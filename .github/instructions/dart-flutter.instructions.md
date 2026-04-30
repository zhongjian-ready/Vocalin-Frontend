---
description: 'Use when editing Dart or Flutter files. Enforce repository architecture, state management, and testing rules.'
applyTo: '**/*.dart'
---

# Dart / Flutter 规范

- 优先沿用当前项目的 `StatelessWidget`、`StatefulWidget`、`provider` 和 `ChangeNotifier` 模式，不无故引入新的状态管理方案。
- 页面代码优先放在 `lib/src/screens/`，可复用组件放在 `lib/src/widgets/`，数据模型放在 `lib/src/models/`，服务逻辑放在 `lib/src/services/`，路由逻辑集中在 `lib/src/navigation/`。
- 涉及鉴权、应用初始化或服务联动时，先检查 `lib/main.dart` 中的 provider 注入链路，以及 `AuthService`、`DataService` 的现有职责边界。
- 涉及导航调整时，优先修改统一路由入口和现有导航结构，不要在页面内部散落临时跳转逻辑。
- 涉及接口、环境变量或远程数据时，优先沿用现有 `dio`、`.env` 和服务层封装方式，不要把请求逻辑直接写到界面层。
- 保持修改最小化，优先复用现有实现，不重构无关代码，不保留未使用的参数、变量、方法、导入和资源。
- 命名必须语义化，除非逻辑确实不直观，否则避免添加注释。
- 新增或修改业务逻辑、服务层或关键交互后，优先补充或更新 `test/` 下对应测试，并至少做一次最小范围验证。