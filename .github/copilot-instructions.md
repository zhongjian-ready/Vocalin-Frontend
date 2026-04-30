# Copilot 说明

## 项目背景

- 这是一个 Flutter 应用项目，主代码位于 `lib/`，入口文件是 `lib/main.dart`。
- 应用主体在 `lib/src/` 下，当前主要目录包括 `models/`、`navigation/`、`screens/`、`services/` 和 `widgets/`。
- 页面按功能拆分在 `lib/src/screens/` 下，当前包含 `auth/`、`home/`、`records/`、`profile/` 以及 `main_screen.dart`。
- 状态管理当前基于 `provider`，`main.dart` 中使用 `MultiProvider` 注入 `AuthService` 和 `DataService`。
- 路由由 `lib/src/navigation/app_router.dart` 统一管理，应用壳在 `lib/src/app.dart`。
- 项目已接入 `.env`，启动时会在 `main.dart` 中加载环境变量；涉及接口地址或环境配置时，优先沿用现有方式。

## 全局要求

- 所有自动生成和修改的代码都必须遵守仓库编码规范，以及 `.github/instructions/` 下与当前文件类型匹配的规则。
- 保持修改尽可能小，并聚焦于需求本身，不重构无关代码。
- 优先复用现有实现，不重复创建已有模式的组件、服务或路由逻辑。
- 优先与附近已有代码保持一致，不引入无必要的新抽象、新状态管理方案或新目录层级。
- 不保留未使用的参数、变量、表达式、方法、导入和资源声明。
- 命名必须语义化，禁止使用无意义命名。
- 除非逻辑确实不直观，否则避免添加注释。
- 不要为文件添加作者、时间等头部注释信息。
- 不要覆盖用户已有修改或无关改动。

## 文件组织与命名

- 新页面优先放在 `lib/src/screens/` 对应业务目录下；仅被单个页面使用的组件，优先放在该页面目录内。
- 可复用 UI 组件放在 `lib/src/widgets/`，业务数据模型放在 `lib/src/models/`，通用服务逻辑放在 `lib/src/services/`。
- 路由相关逻辑集中在 `lib/src/navigation/`，不要把路由判断分散到多个不相关文件中。
- 测试文件放在 `test/` 下，新增测试时优先补充与改动模块直接相关的测试。
- 新增文件和文件夹命名应与 Flutter/Dart 习惯保持一致，优先使用小写加下划线。

## Flutter 开发约束

- 优先沿用当前的 `StatelessWidget` / `StatefulWidget`、`provider` 和 `ChangeNotifier` 模式，不要无故引入新的状态管理库。
- 修改页面结构时，先复用现有 `screens/`、`widgets/` 和 `services/` 内的能力，再决定是否新增实现。
- 涉及异步初始化、鉴权或服务联动时，先检查 `main.dart`、`AuthService` 和 `DataService` 的现有流程，避免破坏 provider 注入链路。
- 涉及导航调整时，优先修改统一路由入口和现有导航结构，避免临时拼接分散跳转逻辑。
- 涉及网络请求或后端接入时，优先沿用现有 `dio`、`.env` 和服务层封装方式，不要把接口调用直接散落到界面层。

## 测试与验证

- 修改完成后，至少对变更文件做一次快速错误检查。
- 如果改动影响业务逻辑、服务层或交互流程，优先补充或更新 `test/` 下的相关测试。
- 当前仓库已有 `test/data_service_test.dart` 和 `test/widget_test.dart`，新增测试时优先参考现有结构和写法。

## 工作方式

- 先搜索现有实现，再决定是否新增组件或逻辑。
- 先从最接近需求的页面、服务或路由入口入手，避免做大范围无关探索。
- 变更后优先做最小范围验证，再决定是否继续扩展修改。
