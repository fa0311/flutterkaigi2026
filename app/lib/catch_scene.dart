import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catch_game.dart';
import 'cached_skin.dart';
import 'character.dart';
import 'drop_models.dart';
import 'studio_lighting.dart';
import 'okayaman_vision.dart';
import 'stage_lighting.dart';
import 'stage_environment.dart';

class CatchScene {
  final scene = Scene();
  final vision = OkayamanVision();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 9.6, 10.8),
    target: vm.Vector3(0, 1.6, 0),
    fovRadiansY: .78,
    fovNear: .1,
    fovFar: 100,
  );
  late Node halo;
  late PhysicallyBasedMaterial _haloMaterial;
  late Node _goodFx, _feverFx, _badFx;
  int _fxEvent = 0;
  // Catch feedback: halo pulse, gold mix of the halo in fever, the camera
  // nudge of a good catch and the rattle of a bad one. All decay on their own.
  double _haloPulse = 0, _feverMix = 0, _kick = 0, _shake = 0;
  // Cartoon squash of the character on a good catch, a flinch on a bad one.
  double _bounce = 0, _flinch = 0;
  final _baseScale = <CatchCharacter, vm.Vector3>{};
  // Sparkles around the character in fever, and sky bursts for milestones.
  late Node _feverAura;
  late final List<Node> _fireworks;
  static const fireworkCount = 6;
  final _pendingFireworks = <({double time, int index, vm.Vector3 position})>[];
  int _fireworkSeed = 0, _nextFirework = 0;
  static const haloMint = (.28, .8, .7), haloGold = (1.0, .74, .18);
  final characters = <CatchCharacter, Node>{};
  final motions = <CatchCharacter, CharacterMotionPlayer>{};
  CatchCharacter displayedCharacter = CatchCharacter.sobaya;
  Map<String, Object?> inspect() => {
    'renderer': {
      'aa': scene.effectiveAntiAliasingMode.name,
      'scale': scene.renderScale,
      'shadowCascades': scene.directionalLight?.shadowCascadeCount,
      'shadowDistance': scene.directionalLight?.shadowMaxDistance,
      'stageVisible': lighting.stage.visible,
      'mountedRoots': scene.root.children.length,
    },
    'displayedCharacter': displayedCharacter.id,
    'motion': motions[displayedCharacter]?.controller.inspect(),
    'facing': facing,
    'catchFx': {
      'good': _goodFx.parent != null,
      'fever': _feverFx.parent != null,
      'bad': _badFx.parent != null,
    },
    'feverMix': _feverMix,
    'shake': _shake,
    'bounce': _bounce,
    'aura': _feverAura.parent != null,
    'fireworks': _fireworks.where((n) => n.parent != null).length,
    'fireworksPending': _pendingFireworks.length,
    'zoom': zoom,
    'vision': vision.inspect(),
    'stage': lighting.inspect(),
    'visibleDropModels': [
      for (final slot in dropSlots)
        for (final d in slot)
          if (d.root.visible) d.kind.name,
    ],
  };
  late StageLighting lighting;
  late EnvironmentMap previewEnvironment;
  final dropModels = DropModels();
  final dropSlots = <List<DropModel>>[];
  final _preparedDropKinds = <CanKind>{};
  double facing = math.pi, clock = 0;

  /// Pinch magnification; 1 is the standard view, larger is closer.
  double zoom = 1;
  double _pivotX = 0;
  // Hidden rigged models still incur a scene-tree walk. Keep reusable models
  // off the live graph until needed; geometry, textures and animation survive.
  void _show(Node node, bool visible) {
    node.visible = visible;
    if (visible && node.parent == null) {
      scene.add(node);
    } else if (!visible && identical(node.parent, scene.root)) {
      scene.remove(node);
    }
  }

  void applyRenderProbe(Map<String, String> p) {
    lighting.configureRenderer(scene);
    scene.antiAliasingMode = switch (p['aa']) {
      'fxaa' => AntiAliasingMode.fxaa,
      'none' => AntiAliasingMode.none,
      'msaa' => AntiAliasingMode.auto,
      _ => scene.antiAliasingMode,
    };
    scene.renderScale =
        double.tryParse(p['scale'] ?? '') ?? lighting.renderScale;
    scene.directionalLight
      ?..shadowCascadeCount =
          int.tryParse(p['cascades'] ?? '') ?? lighting.graphics.shadowCascades
      ..shadowMaxDistance =
          double.tryParse(p['shadowDistance'] ?? '') ??
          lighting.graphics.shadowDistance
      ..shadowMapResolution = int.tryParse(p['shadowSize'] ?? '') ?? 1024;
  }

  PhysicallyBasedMaterial mat(
    double r,
    double g,
    double b, {
    double metal = 0,
  }) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..roughnessFactor = .6
    ..metallicFactor = metal;
  Node mesh(Geometry geo, Material material, vm.Vector3 pos) {
    final n = Node(mesh: Mesh(geo, material))..position = pos;
    scene.add(n);
    return n;
  }

  Future<void> load() async {
    await Scene.initializeStaticResources();
    previewEnvironment = await beerStudioEnvironment();
    final cityMaps = await cityEnvironments();
    final akasaka = await loadScene('assets/models/akasaka.glb');
    akasaka.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    // Night work lights on the support-building roofs keep the beam readable.
    final workLights = <PointLight>[];
    for (final x in [-4.9, 4.9]) {
      final light = PointLight(
        color: vm.Vector3(1, .86, .66),
        intensity: 0,
        range: 14,
        falloffExponent: 1.2,
      );
      workLights.add(light);
      final node = Node()..position = vm.Vector3(x, 3.2, 2.4);
      node.addComponent(PointLightComponent(light));
      scene.add(node);
    }
    // Flag static shadow casters before mounting so they enter the cache.
    lighting = StageLighting(akasaka, workLights, cityMaps);
    scene.add(akasaka);
    for (final character in CatchCharacter.values) {
      final node = await loadScene(character.modelAsset);
      cacheSkinUploads(node);
      characters[character] = node;
      _baseScale[character] = node.scale.clone();
      scene.add(node);
      motions[character] = CharacterMotionPlayer(
        node,
        sources: const {'Idle': 'Idle', 'Walk': 'Walk'},
        groundSpeeds: const {'Walk': 1.5},
      );
    }
    _haloMaterial = mat(haloMint.$1, haloMint.$2, haloMint.$3);
    halo = mesh(
      TorusGeometry(
        radius: .7,
        tubeRadius: .025,
        radialSegments: 40,
        tubularSegments: 6,
      ),
      _haloMaterial,
      vm.Vector3(0, .04, 0),
    );
    _goodFx = _catchBurst(
      from: vm.Vector4(.7, 1.8, 1.6, 1),
      to: vm.Vector4(1.5, 1.6, 1.3, 1),
      gravity: vm.Vector3(0, -3.2, 0),
      angle: .9,
      count: 18,
    );
    // From the fever combo the burst turns gold and denser.
    _feverFx = _catchBurst(
      from: vm.Vector4(2.4, 1.7, .5, 1),
      to: vm.Vector4(1.9, .9, .2, 1),
      gravity: vm.Vector3(0, -2.6, 0),
      angle: 1.1,
      count: 24,
    );
    _badFx = _catchBurst(
      from: vm.Vector4(1.9, .28, .16, 1),
      to: vm.Vector4(1.2, .08, .05, .9),
      gravity: vm.Vector3(0, 2.4, 0),
      angle: .45,
      count: 14,
    );
    _feverAura = _aura();
    const fireworkColors = [
      (2.4, 1.7, .5),
      (.5, 2.2, 1.9),
      (2.3, .6, 1.4),
      (.6, 1.2, 2.5),
      (2.2, 2.2, 2.2),
      (2.4, 1.0, .3),
    ];
    _fireworks = [
      for (var i = 0; i < fireworkCount; i++) _firework(fireworkColors[i]),
    ];

    await dropModels.load();
    // At most ceil((6 + .65) / .5) = 14 simultaneously visible drops. Clones
    // are created on first use, then reused. Do not preallocate every
    // character/item combination for all 16 slots.
    for (var slot = 0; slot < 16; slot++) {
      dropSlots.add(<DropModel>[]);
    }
    await vision.load(scene);
    update(CatchGame(), 0);
  }

  /// One-shot additive burst. Left off the scene graph until a catch.
  Node _catchBurst({
    required vm.Vector4 from,
    required vm.Vector4 to,
    required vm.Vector3 gravity,
    required double angle,
    required int count,
  }) {
    final node = Node();
    node.addComponent(
      ParticleEmitterComponent(
        system: ParticleSystem(
          maxParticles: 24,
          looping: false,
          duration: .05,
          seed: 1,
          shape: ConeEmitterShape(angle: angle, radius: .12),
          spawner: Spawner(bursts: [ParticleBurst(time: 0, count: count)]),
          lifetime: const UniformFloat(.28, .48),
          startSpeed: const UniformFloat(1.4, 2.6),
          startSize: const UniformFloat(.12, .26),
          startColor: UniformColor(from, to),
          gravity: gravity,
          modules: [
            SizeOverLifeModule(
              CurveFloat(ParticleCurve.linear(from: 1, to: 0)),
            ),
            ColorOverLifeModule(
              GradientColor(
                ColorGradient([
                  ColorStop(0, from),
                  ColorStop(1, vm.Vector4(to.x, to.y, to.z, 0)),
                ]),
              ),
            ),
          ],
        ),
        material: SpriteMaterial()..blendMode = SpriteBlendMode.additive,
      ),
    );
    return node;
  }

  /// Sparkles drifting up around the character while the combo is in fever.
  Node _aura() {
    final gold = vm.Vector4(2.4, 1.8, .5, 1),
        mint = vm.Vector4(.7, 2.2, 1.8, 1);
    final node = Node();
    node.addComponent(
      ParticleEmitterComponent(
        system: ParticleSystem(
          maxParticles: 64,
          looping: true,
          duration: 1,
          seed: 3,
          shape: const SphereEmitterShape(radius: .55),
          spawner: Spawner(rate: 45),
          lifetime: const UniformFloat(.5, .9),
          startSpeed: const UniformFloat(.4, 1.1),
          startSize: const UniformFloat(.07, .15),
          startColor: UniformColor(gold, mint),
          gravity: vm.Vector3(0, 1.8, 0),
          modules: [
            SizeOverLifeModule(
              CurveFloat(ParticleCurve.linear(from: 1, to: 0)),
            ),
            ColorOverLifeModule(
              GradientColor(
                ColorGradient([
                  ColorStop(0, gold),
                  ColorStop(1, vm.Vector4(mint.x, mint.y, mint.z, 0)),
                ]),
              ),
            ),
          ],
        ),
        material: SpriteMaterial()..blendMode = SpriteBlendMode.additive,
      ),
    );
    return node;
  }

  /// A sky burst for the combo milestones: white core, then [rgb].
  Node _firework((double, double, double) rgb) {
    final from = vm.Vector4(rgb.$1, rgb.$2, rgb.$3, 1),
        white = vm.Vector4(2.4, 2.4, 2.4, 1);
    final node = Node();
    node.addComponent(
      ParticleEmitterComponent(
        system: ParticleSystem(
          maxParticles: 64,
          looping: false,
          duration: .05,
          seed: 5,
          shape: const SphereEmitterShape(radius: .15, surfaceOnly: true),
          spawner: Spawner(bursts: [const ParticleBurst(time: 0, count: 56)]),
          lifetime: const UniformFloat(.7, 1.2),
          startSpeed: const UniformFloat(3.2, 5.2),
          startSize: const UniformFloat(.14, .28),
          startColor: UniformColor(from, white),
          gravity: vm.Vector3(0, -2.4, 0),
          modules: [
            SizeOverLifeModule(
              CurveFloat(ParticleCurve.linear(from: 1, to: 0)),
            ),
            ColorOverLifeModule(
              GradientColor(
                ColorGradient([
                  ColorStop(0, white),
                  ColorStop(.25, from),
                  ColorStop(1, vm.Vector4(from.x, from.y, from.z, 0)),
                ]),
              ),
            ),
          ],
        ),
        material: SpriteMaterial()..blendMode = SpriteBlendMode.additive,
      ),
    );
    return node;
  }

  /// Schedules [count] fireworks over the stage, one every 0.16 s.
  void launchFireworks(int count) {
    final r = math.Random(_fireworkSeed++);
    for (var i = 0; i < count; i++) {
      _nextFirework = (_nextFirework + 1) % fireworkCount;
      _pendingFireworks.add((
        time: clock + i * .16,
        index: _nextFirework,
        // Over the skyline behind the beam: the camera looks down at the
        // beam, so the visible sky at this depth is roughly y 5 to 7.5.
        position: vm.Vector3(
          (r.nextDouble() - .5) * 11,
          5.2 + r.nextDouble() * 2,
          -6 + r.nextDouble() * 3,
        ),
      ));
    }
  }

  void _syncFireworks() {
    _pendingFireworks.removeWhere((f) {
      if (f.time > clock) return false;
      final node = _fireworks[f.index];
      node.getComponent<ParticleEmitterComponent>()!.system.reset();
      node.position = f.position;
      _show(node, true);
      return true;
    });
    for (final node in _fireworks) {
      _retireCatchFx(node);
    }
  }

  void _playCatchFx(Node node, double x, int event, {required bool flip}) {
    node.getComponent<ParticleEmitterComponent>()!.system.reset();
    node.position = vm.Vector3(x, catchHeight, 0);
    // reset() replays the fixed seed, so turn each burst about Y by the golden
    // angle to keep repeats from looking identical. Local +Y is the cone axis;
    // flip it so a bad catch falls.
    final turn = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), event * 2.39996);
    node.rotation = flip
        ? turn * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi)
        : turn;
    _show(node, true);
  }

  void _retireCatchFx(Node node) {
    final system = node.getComponent<ParticleEmitterComponent>()!.system;
    if (node.parent != null &&
        system.time > 0 &&
        system.storage.aliveCount == 0) {
      _show(node, false);
    }
  }

  void _syncCatchFx(CatchGame g, double dt) {
    if (g.eventId != _fxEvent) {
      _fxEvent = g.eventId;
      final x = g.fxX;
      if (x == null) {
        _show(_goodFx, false);
        _show(_feverFx, false);
        _show(_badFx, false);
        for (final node in _fireworks) {
          _show(node, false);
        }
        _pendingFireworks.clear();
        _haloPulse = 0;
        _kick = 0;
        _shake = 0;
        _bounce = 0;
        _flinch = 0;
      } else if (g.fxBad) {
        _playCatchFx(_badFx, x, g.eventId, flip: true);
        _haloPulse = 0;
        _shake = 1;
        _flinch = 1;
      } else {
        _playCatchFx(g.fever ? _feverFx : _goodFx, x, g.eventId, flip: false);
        _haloPulse = 1;
        _kick = 1;
        _shake = .45;
        _bounce = 1;
      }
    } else if (dt > 0) {
      _haloPulse *= math.exp(-8 * dt);
      _kick *= math.exp(-10 * dt);
      _shake *= math.exp(-9 * dt);
      _bounce *= math.exp(-7 * dt);
      _flinch *= math.exp(-6 * dt);
    }
    _syncFireworks();
    _retireCatchFx(_goodFx);
    _retireCatchFx(_feverFx);
    _retireCatchFx(_badFx);
    final feverTarget = g.fever ? 1.0 : 0.0;
    _feverMix +=
        (feverTarget - _feverMix) * (dt <= 0 ? 1 : 1 - math.exp(-dt * 6));
    _haloMaterial.baseColorFactor = vm.Vector4(
      haloMint.$1 + (haloGold.$1 - haloMint.$1) * _feverMix,
      haloMint.$2 + (haloGold.$2 - haloMint.$2) * _feverMix,
      haloMint.$3 + (haloGold.$3 - haloMint.$3) * _feverMix,
      1,
    );
  }

  void update(CatchGame g, double dt) {
    clock += dt;
    lighting.time = g.timeOfDay;
    lighting.apply(scene);
    lighting.update(clock);
    displayedCharacter = g.phase == Phase.ready || g.phase == Phase.result
        ? g.selectedCharacter
        : g.roundCharacter;
    for (final entry in characters.entries) {
      _show(entry.value, entry.key == displayedCharacter);
    }
    final character = characters[displayedCharacter]!;
    // Prepare only this player's two/three item types on selection, before
    // the countdown. Avoid first-spawn cloning during the round.
    for (final kind in [
      ...displayedCharacter.goodDrops,
      displayedCharacter.badDrop,
    ]) {
      if (_preparedDropKinds.add(kind)) {
        for (final slot in dropSlots) {
          slot.add(dropModels.create(kind));
        }
      }
    }
    final motion = motions[displayedCharacter]!;
    final speed = g.vx.abs();
    motion.controller.select(speed > .15 ? 'Walk' : 'Idle');
    motion.controller.advance(dt, groundSpeed: speed);
    motion.sample();
    if (speed > .12) {
      final desired = math.atan2(-g.vx, 0),
          diff = math.atan2(
            math.sin(desired - facing),
            math.cos(desired - facing),
          );
      facing += diff * (1 - math.exp(-dt * 12));
    }
    character.position = vm.Vector3(g.x, 0, 0);
    character.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing);
    final rest = _baseScale[displayedCharacter] ?? vm.Vector3(1, 1, 1);
    character.scale = vm.Vector3(
      rest.x * (1 + .22 * _bounce + .1 * _flinch),
      rest.y * (1 - .28 * _bounce - .18 * _flinch),
      rest.z * (1 + .22 * _bounce + .1 * _flinch),
    );
    final radius = g.phase == Phase.ready || g.phase == Phase.result
        ? displayedCharacter.catchRadius
        : g.catchRadius;
    _syncCatchFx(g, dt);
    halo.position = vm.Vector3(g.x, .04, 0);
    _show(_feverAura, g.fever && g.phase == Phase.playing);
    _feverAura.position = vm.Vector3(g.x, .9, 0);
    final pulse = 1 + .28 * _haloPulse + .1 * _feverMix * math.sin(clock * 14);
    halo.scale = vm.Vector3(radius / .7 * pulse, 1, .52 * pulse);
    final widen = 1 + .18 * math.sin(g.yaw * 2).abs();
    final base = vm.Vector3(
      math.sin(g.yaw) * 10.8 * widen,
      5.0 * widen,
      math.cos(g.yaw) * 10.8 * widen,
    );
    // Leave sky between the 333m landmark tip and the HUD on wide iPhones.
    final baseTarget = vm.Vector3(0, 2.9, 0);
    final m = zoom;
    // Pinch zooms toward the character. Smoothed so the end stops and quick
    // reversals don't jolt the view.
    _pivotX += (g.x - _pivotX) * (dt <= 0 ? 1 : 1 - math.exp(-dt * 6));
    // Closer views aim lower, toward the beam and the character's body.
    final close = ((m - 1) / math.max(.01, g.balance['zoomMax'] - 1)).clamp(
      0.0,
      1.0,
    );
    final target = vm.Vector3(
      _pivotX,
      baseTarget.y + (1.0 - baseTarget.y) * close,
      0,
    );
    camera.target = target;
    camera.position = target + (base - baseTarget) / m;
    // A good catch nudges the view in for a beat; a bad one rattles and
    // rolls it.
    if (_kick > 1e-3 || _shake > 1e-3) {
      camera.position =
          camera.position +
          (target - camera.position) * (.05 * _kick) +
          vm.Vector3(math.sin(clock * 61) * .2, math.cos(clock * 47) * .13, 0) *
              _shake;
    }
    camera.up = vm.Vector3(math.sin(clock * 53) * .08 * _shake, 1, 0);
    final visible = g.phase == Phase.ready
        ? <Drop>[]
        : g.drops.where((d) => d.visible(g.time)).toList();
    for (var i = 0; i < dropSlots.length; i++) {
      final active = i < visible.length;
      if (active && !dropSlots[i].any((m) => m.kind == visible[i].kind)) {
        dropSlots[i].add(dropModels.create(visible[i].kind));
      }
      for (final model in dropSlots[i]) {
        _show(model.root, active && visible[i].kind == model.kind);
      }
      if (!active) continue;
      final d = visible[i], age = g.time - d.spawn;
      final drop = dropSlots[i].firstWhere((m) => m.kind == d.kind);
      drop.sample(age);
      drop.root.position = vm.Vector3(
        d.x,
        d.resolved && !d.caught
            ? catchHeight - math.pow((g.time - d.settled) * 5, 2).toDouble()
            : d.height(g.time),
        0,
      );
      // Every drop keeps its own heading instead of facing the camera.
      drop.root.rotation =
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            d.facing +
                (d.kind.isCan ? math.pi : .25 * math.sin(age)) +
                math.sin(age * 2) * .08,
          ) *
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            math.sin(age * 3 + d.id) * .10,
          );
    }
  }
}
