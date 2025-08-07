# MetalShooter 项目文件结构

```
MetalShooter/
│
├── MetalShooter.xcodeproj/           # Xcode 项目文件
│   ├── project.pbxproj
│   └── xcuserdata/
│
├── MetalShooter/                     # 主应用目标
│   │
│   ├── Application/                  # 应用程序层
│   │   ├── AppDelegate.swift
│   │   ├── ShooterGameApp.swift
│   │   ├── GameWindow.swift
│   │   ├── GameViewController.swift
│   │   └── Info.plist
│   │
│   ├── Engine/                       # 游戏引擎核心
│   │   ├── Core/
│   │   │   ├── GameEngine.swift
│   │   │   ├── GameLoop.swift
│   │   │   ├── Time.swift
│   │   │   └── GameSettings.swift
│   │   │
│   │   ├── Scene/
│   │   │   ├── SceneManager.swift
│   │   │   ├── Scene.swift
│   │   │   ├── Camera.swift
│   │   │   └── Transform.swift
│   │   │
│   │   └── Math/
│   │       ├── MathTypes.swift
│   │       ├── Matrix.swift
│   │       ├── Vector.swift
│   │       ├── Quaternion.swift
│   │       └── AABB.swift
│   │
│   ├── ECS/                          # 实体组件系统
│   │   ├── Core/
│   │   │   ├── EntityManager.swift
│   │   │   ├── Entity.swift
│   │   │   ├── Component.swift
│   │   │   └── ComponentType.swift
│   │   │
│   │   ├── Components/
│   │   │   ├── TransformComponent.swift
│   │   │   ├── RenderComponent.swift
│   │   │   ├── WeaponComponent.swift
│   │   │   ├── HealthComponent.swift
│   │   │   ├── AIComponent.swift
│   │   │   ├── PhysicsComponent.swift
│   │   │   ├── AudioComponent.swift
│   │   │   └── PlayerComponent.swift
│   │   │
│   │   └── Systems/
│   │       ├── GameSystem.swift
│   │       ├── PlayerSystem.swift
│   │       ├── AISystem.swift
│   │       ├── WeaponSystem.swift
│   │       ├── PhysicsSystem.swift
│   │       ├── RenderSystem.swift
│   │       ├── AudioSystem.swift
│   │       └── SystemsManager.swift
│   │
│   ├── Rendering/                    # 渲染系统
│   │   ├── Core/
│   │   │   ├── MetalRenderer.swift
│   │   │   ├── RenderPipeline.swift
│   │   │   ├── MetalDevice.swift
│   │   │   └── MetalView.swift
│   │   │
│   │   ├── Passes/
│   │   │   ├── RenderPass.swift
│   │   │   ├── GeometryPass.swift
│   │   │   ├── LightingPass.swift
│   │   │   ├── ShadowPass.swift
│   │   │   ├── PostProcessPass.swift
│   │   │   └── UIPass.swift
│   │   │
│   │   ├── Resources/
│   │   │   ├── Mesh.swift
│   │   │   ├── Material.swift
│   │   │   ├── Texture.swift
│   │   │   ├── Shader.swift
│   │   │   └── Buffer.swift
│   │   │
│   │   ├── Lighting/
│   │   │   ├── Light.swift
│   │   │   ├── DirectionalLight.swift
│   │   │   ├── PointLight.swift
│   │   │   ├── SpotLight.swift
│   │   │   └── LightingSystem.swift
│   │   │
│   │   └── Optimization/
│   │       ├── CullingSystem.swift
│   │       ├── LODSystem.swift
│   │       ├── BatchingSystem.swift
│   │       └── PerformanceOptimizer.swift
│   │
│   ├── Shaders/                      # Metal 着色器
│   │   ├── Common/
│   │   │   ├── ShaderTypes.h
│   │   │   ├── Common.metal
│   │   │   └── Vertex.metal
│   │   │
│   │   ├── Geometry/
│   │   │   ├── GeometryVertex.metal
│   │   │   ├── GeometryFragment.metal
│   │   │   └── InstancedGeometry.metal
│   │   │
│   │   ├── Lighting/
│   │   │   ├── DeferredLighting.metal
│   │   │   ├── ShadowMapping.metal
│   │   │   └── PBR.metal
│   │   │
│   │   ├── PostProcess/
│   │   │   ├── Bloom.metal
│   │   │   ├── ToneMapping.metal
│   │   │   ├── FXAA.metal
│   │   │   └── ScreenSpaceEffects.metal
│   │   │
│   │   └── Compute/
│   │       ├── ParticleSimulation.metal
│   │       ├── Culling.metal
│   │       └── GPUSort.metal
│   │
│   ├── Physics/                      # 物理系统
│   │   ├── Core/
│   │   │   ├── PhysicsWorld.swift
│   │   │   ├── PhysicsSystem.swift
│   │   │   ├── RigidBody.swift
│   │   │   └── PhysicMaterial.swift
│   │   │
│   │   ├── Collision/
│   │   │   ├── Collider.swift
│   │   │   ├── BoxCollider.swift
│   │   │   ├── SphereCollider.swift
│   │   │   ├── CapsuleCollider.swift
│   │   │   ├── MeshCollider.swift
│   │   │   └── CollisionDetection.swift
│   │   │
│   │   ├── Dynamics/
│   │   │   ├── Force.swift
│   │   │   ├── Constraint.swift
│   │   │   └── Solver.swift
│   │   │
│   │   └── Raycast/
│   │       ├── Ray.swift
│   │       ├── RaycastHit.swift
│   │       └── RaycastSystem.swift
│   │
│   ├── AI/                           # AI 系统
│   │   ├── Core/
│   │   │   ├── AISystem.swift
│   │   │   ├── AIAgent.swift
│   │   │   └── AIBehaviorTree.swift
│   │   │
│   │   ├── States/
│   │   │   ├── AIState.swift
│   │   │   ├── PatrolState.swift
│   │   │   ├── AlertState.swift
│   │   │   ├── CombatState.swift
│   │   │   ├── PursueState.swift
│   │   │   ├── SearchState.swift
│   │   │   └── RetreatState.swift
│   │   │
│   │   ├── Navigation/
│   │   │   ├── PathfindingSystem.swift
│   │   │   ├── NavigationMesh.swift
│   │   │   ├── AStar.swift
│   │   │   └── NavMeshAgent.swift
│   │   │
│   │   └── Sensors/
│   │       ├── VisionSensor.swift
│   │       ├── HearingSensor.swift
│   │       └── ProximitySensor.swift
│   │
│   ├── Input/                        # 输入系统
│   │   ├── Core/
│   │   │   ├── InputManager.swift
│   │   │   ├── InputEvent.swift
│   │   │   └── InputBinding.swift
│   │   │
│   │   ├── Handlers/
│   │   │   ├── KeyboardHandler.swift
│   │   │   ├── MouseHandler.swift
│   │   │   └── ControllerHandler.swift
│   │   │
│   │   └── Types/
│   │       ├── KeyCode.swift
│   │       ├── ControllerInput.swift
│   │       └── ControllerButton.swift
│   │
│   ├── Audio/                        # 音频系统
│   │   ├── Core/
│   │   │   ├── AudioManager.swift
│   │   │   ├── AudioEngine.swift
│   │   │   └── Audio3D.swift
│   │   │
│   │   ├── Components/
│   │   │   ├── AudioSource.swift
│   │   │   ├── AudioClip.swift
│   │   │   └── AudioListener.swift
│   │   │
│   │   └── Effects/
│   │       ├── Reverb.swift
│   │       ├── Echo.swift
│   │       └── Distortion.swift
│   │
│   ├── Gameplay/                     # 游戏玩法
│   │   ├── Player/
│   │   │   ├── PlayerController.swift
│   │   │   ├── FirstPersonCamera.swift
│   │   │   └── MouseLook.swift
│   │   │
│   │   ├── Weapons/
│   │   │   ├── Weapon.swift
│   │   │   ├── Gun.swift
│   │   │   ├── Rifle.swift
│   │   │   ├── Pistol.swift
│   │   │   ├── Shotgun.swift
│   │   │   ├── Bullet.swift
│   │   │   └── WeaponType.swift
│   │   │
│   │   ├── Enemies/
│   │   │   ├── Enemy.swift
│   │   │   ├── BasicEnemy.swift
│   │   │   ├── EliteEnemy.swift
│   │   │   └── BossEnemy.swift
│   │   │
│   │   ├── Items/
│   │   │   ├── Item.swift
│   │   │   ├── HealthPack.swift
│   │   │   ├── AmmoPack.swift
│   │   │   └── PowerUp.swift
│   │   │
│   │   └── Effects/
│   │       ├── ParticleSystem.swift
│   │       ├── Explosion.swift
│   │       ├── MuzzleFlash.swift
│   │       └── BloodEffect.swift
│   │
│   ├── World/                        # 世界管理
│   │   ├── Core/
│   │   │   ├── WorldManager.swift
│   │   │   ├── Level.swift
│   │   │   └── Spawn.swift
│   │   │
│   │   ├── Environment/
│   │   │   ├── Terrain.swift
│   │   │   ├── StaticMesh.swift
│   │   │   ├── Skybox.swift
│   │   │   └── Weather.swift
│   │   │
│   │   └── Loading/
│   │       ├── LevelLoader.swift
│   │       ├── AssetStreaming.swift
│   │       └── WorldSerializer.swift
│   │
│   ├── UI/                           # 用户界面
│   │   ├── Core/
│   │   │   ├── UIManager.swift
│   │   │   ├── UIRenderer.swift
│   │   │   └── UIElement.swift
│   │   │
│   │   ├── HUD/
│   │   │   ├── HUDManager.swift
│   │   │   ├── HealthBar.swift
│   │   │   ├── AmmoCounter.swift
│   │   │   ├── Crosshair.swift
│   │   │   ├── MiniMap.swift
│   │   │   └── DamageIndicator.swift
│   │   │
│   │   ├── Menus/
│   │   │   ├── MainMenu.swift
│   │   │   ├── PauseMenu.swift
│   │   │   ├── SettingsMenu.swift
│   │   │   ├── LoadingScreen.swift
│   │   │   └── GameOverScreen.swift
│   │   │
│   │   └── Controls/
│   │       ├── Button.swift
│   │       ├── Slider.swift
│   │       ├── Label.swift
│   │       └── Panel.swift
│   │
│   ├── Resources/                    # 资源管理
│   │   ├── Core/
│   │   │   ├── ResourceManager.swift
│   │   │   ├── AssetLoader.swift
│   │   │   └── ResourceCache.swift
│   │   │
│   │   ├── Loaders/
│   │   │   ├── TextureLoader.swift
│   │   │   ├── MeshLoader.swift
│   │   │   ├── MaterialLoader.swift
│   │   │   ├── AudioLoader.swift
│   │   │   └── LevelLoader.swift
│   │   │
│   │   └── Pool/
│   │       ├── ObjectPool.swift
│   │       ├── BulletPool.swift
│   │       ├── ParticlePool.swift
│   │       └── EffectPool.swift
│   │
│   ├── Utilities/                    # 工具类
│   │   ├── Extensions/
│   │   │   ├── MTLDevice+Extensions.swift
│   │   │   ├── simd+Extensions.swift
│   │   │   ├── String+Extensions.swift
│   │   │   └── URL+Extensions.swift
│   │   │
│   │   ├── Helpers/
│   │   │   ├── FileHelper.swift
│   │   │   ├── MathHelper.swift
│   │   │   ├── ColorHelper.swift
│   │   │   └── GeometryHelper.swift
│   │   │
│   │   ├── Debug/
│   │   │   ├── DebugRenderer.swift
│   │   │   ├── Logger.swift
│   │   │   ├── Profiler.swift
│   │   │   └── MemoryMonitor.swift
│   │   │
│   │   └── Patterns/
│   │       ├── Singleton.swift
│   │       ├── Observer.swift
│   │       ├── Factory.swift
│   │       └── Command.swift
│   │
│   └── Configuration/                # 配置文件
│       ├── GameConfig.swift
│       ├── RenderConfig.swift
│       ├── AudioConfig.swift
│       ├── InputConfig.swift
│       └── Constants.swift
│
├── Assets/                          # 游戏资源
│   ├── Textures/
│   │   ├── Characters/
│   │   ├── Weapons/
│   │   ├── Environment/
│   │   ├── Effects/
│   │   └── UI/
│   │
│   ├── Models/
│   │   ├── Characters/
│   │   │   ├── Player/
│   │   │   └── Enemies/
│   │   ├── Weapons/
│   │   ├── Environment/
│   │   └── Items/
│   │
│   ├── Audio/
│   │   ├── SFX/
│   │   │   ├── Weapons/
│   │   │   ├── Footsteps/
│   │   │   ├── Impacts/
│   │   │   └── UI/
│   │   ├── Music/
│   │   │   ├── Menu/
│   │   │   ├── Gameplay/
│   │   │   └── Ambient/
│   │   └── Voice/
│   │       ├── Player/
│   │       └── Enemies/
│   │
│   ├── Materials/
│   │   ├── PBR/
│   │   ├── Unlit/
│   │   └── PostProcess/
│   │
│   ├── Levels/
│   │   ├── Level01/
│   │   ├── Level02/
│   │   └── TestLevel/
│   │
│   ├── Fonts/
│   │   ├── UI/
│   │   └── Debug/
│   │
│   └── Prefabs/
│       ├── Player/
│       ├── Enemies/
│       ├── Weapons/
│       ├── Items/
│       └── Effects/
│
├── MetalShooterTests/               # 单元测试
│   ├── Core/
│   │   ├── GameEngineTests.swift
│   │   ├── EntityManagerTests.swift
│   │   └── MathTests.swift
│   │
│   ├── Systems/
│   │   ├── PhysicsSystemTests.swift
│   │   ├── AISystemTests.swift
│   │   └── WeaponSystemTests.swift
│   │
│   ├── Rendering/
│   │   ├── MetalRendererTests.swift
│   │   └── CullingTests.swift
│   │
│   ├── Utilities/
│   │   └── UtilityTests.swift
│   │
│   └── Resources/
│       └── TestAssets/
│
├── MetalShooterUITests/             # UI 测试
│   ├── MenuTests.swift
│   ├── GameplayTests.swift
│   └── PerformanceTests.swift
│
├── Tools/                           # 开发工具
│   ├── AssetPipeline/
│   │   ├── TextureProcessor.swift
│   │   ├── MeshProcessor.swift
│   │   └── AudioProcessor.swift
│   │
│   ├── LevelEditor/
│   │   ├── EditorViewController.swift
│   │   ├── SceneHierarchy.swift
│   │   └── PropertyInspector.swift
│   │
│   └── BuildScripts/
│       ├── build.sh
│       ├── deploy.sh
│       └── test.sh
│
├── Documentation/                   # 文档
│   ├── API/
│   ├── TechnicalSpecs/
│   ├── GameDesign/
│   └── UserManual/
│
├── .gitignore
├── README.md
├── CHANGELOG.md
├── LICENSE
└── Podfile                         # 依赖管理 (如果使用 CocoaPods)
```

## 文件命名约定

### Swift 文件
- **类和结构体**: PascalCase (例: `GameEngine.swift`)
- **协议**: PascalCase + Protocol 后缀 (例: `RenderableProtocol.swift`)
- **枚举**: PascalCase (例: `WeaponType.swift`)
- **扩展**: 原类型名 + Extensions (例: `String+Extensions.swift`)

### Metal 文件
- **着色器文件**: 功能描述.metal (例: `GeometryVertex.metal`)
- **头文件**: 功能描述.h (例: `ShaderTypes.h`)

### 资源文件
- **纹理**: 小写_用途.格式 (例: `player_diffuse.png`)
- **模型**: 小写_描述.格式 (例: `assault_rifle.obj`)
- **音频**: 小写_描述.格式 (例: `gunshot_pistol.wav`)

## 组织原则

1. **模块化**: 每个系统独立成文件夹
2. **分层**: 按照架构层次组织代码
3. **职责单一**: 每个文件专注于单一功能
4. **依赖管理**: 高层次不依赖低层次
5. **测试友好**: 便于单元测试的结构

## 关键文件说明

### 核心启动文件
- `AppDelegate.swift`: macOS 应用程序入口
- `ShooterGameApp.swift`: 游戏应用程序主类
- `GameViewController.swift`: 主游戏视图控制器

### 引擎核心
- `GameEngine.swift`: 游戏引擎主类
- `GameLoop.swift`: 游戏主循环
- `EntityManager.swift`: ECS 系统核心

### 渲染核心
- `MetalRenderer.swift`: Metal 渲染器主类
- `RenderPipeline.swift`: 渲染管线管理
- 各种 `.metal` 文件: GPU 着色器代码

### 配置文件
- `Info.plist`: 应用程序配置
- `GameConfig.swift`: 游戏配置参数
- `Constants.swift`: 全局常量定义

这个结构支持大型游戏项目的开发，便于团队协作和代码维护。
