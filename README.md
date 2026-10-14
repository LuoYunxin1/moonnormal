# MoonNormal

**有预算上限的关系数据库模式规范化与分解验证库。**

MoonNormal 将给定函数依赖转成可检查的候选键、2NF/3NF/BCNF 诊断、
3NF 综合和 BCNF 分解，并检查依赖保持与无损连接。
它也能生成有损分解的有限反例、审计字符串元组和比较迁移前后的布局。
它不是 SQL 执行器，也不从少量观察数据推断普遍成立的依赖。

## 安装

需要支持现代 `moon.mod` 的 MoonBit。验收使用官方
`moonc v0.10.15+943464bfa` / `moon 0.1.20261012 (748b63c)`。

```sh
moon add LuoYunxin1/moonnormal@0.1.0
```

下游 `moon.pkg`：

```moonbit
import {
  "LuoYunxin1/moonnormal" @normal,
}
```

## 使用

```moonbit
let s = @normal.parse_schema_text(
  "attributes: Student,Course,Tutor\nStudent,Course -> Tutor\nTutor -> Course",
)
let third = s.synthesize_3nf()
let bcnf = s.decompose_bcnf()
let audit = s.audit_plan(bcnf)
// BCNF 无损，但可能不保持 Student,Course -> Tutor。
let report = s.plan_report(bcnf)
```

这些调用会抛出 `DesignError`，在调用函数声明 `raise` 或用 `catch` 处理。
`Invalid` 表示不合约的输入；`Budget` 表示预算不足，**不是否定的数学结论**。

## API 分组

- 建模：`schema`、`parse_schema_text`、`resolve`、`names`、`closure`、`entails`。
- 键：`candidate_keys`、`is_candidate_key`、`key_profile`、`prime_attributes`。
- 理论：`minimal_cover`、`grouped_cover`、`equivalent`、`compare_theory`。
- 规范化：`normal_form_violations`、`relation_profile`、`synthesize_3nf`、`decompose_bcnf`。
- 分解验收：`project_dependencies`、`dependency_preservation`、`binary_lossless`、
  `lossless_chase`、`audit_plan`、`verify_split_trace`、`verify_chase_trace`。
- 反例：`lossy_counterexample`、`verify_lossy_counterexample`。
- 数据：`table`、`project`、`natural_join`、`reconstruct`、`audit_dependencies`、
  `key_collisions`、`column_profiles`。
- 集成：Schema/Table/Plan JSON，CSV，`dependency_locality`、`review_migration`、
  `sql_advice` 和可读报告。完整签名见 `pkg.generated.mbti`。

## 三个完整示例

```sh
moon run examples/design
moon run examples/migration
moon run examples/quality
```

示例分别完成数据库设计取舍、迁移回归审查和 CSV 数据质量审计；
每个示例包含断言，详细输入输出见 [examples](examples/README.md)。

## 数据和边界

- 属性为 1–16 个有序唯一 ASCII 标识符，声明 FD 至多 256 条。
  属性索引从 0 开始；FD 内部集合会规范化，表列必须已排序且唯一。
- 属性/依赖/表输入会复制，Schema/Table 字段私有，getter 返回副本。
  公开结果记录可修改；不得将外部修改后的计划或轨迹当作认证证明。
- 空决定项允许表示常量依赖。`candidate_keys(relation=[] )` 表示整关系；
  单独判断空关系请用 `is_candidate_key([], [])`。
- 元组是字符串集合，重复行去重，空串是普通值，**不模拟 SQL NULL**。
  FD 违规行号指向去重后的输入顺序。
- 子集枚举是指数级。默认预算 work=2,000,000、results=4,096、rows=4,096、
  cells=65,536；16 属性是验证上限，并非所有 16 属性任务都能在默认预算完成。
- JSON 版本字段必须匹配且不接受额外字段；core JSON 对重复对象键采用末项，
  此格式不用于签名、安全规范化或不可信深层结构。CSV 支持双引号、换行、CRLF，
  不接受无引号字段中的引号或闭引号后的多余字符。
- Chase 的结构校验 `validate_chase_witness` 只检查定点与证据行的一致性；
  证明来源使用确定性重算的 `verify_chase_trace`。
- SQL 输出只有建议性 TEXT NOT NULL / PRIMARY KEY；不能保证任意 FD，
  不推导外键，不执行迁移。MVD、4NF/5NF、SQL AST/优化器/ORM 不在范围内。

## 复现

```sh
moon info
moon fmt --check
moon check --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
moon build --target wasm-gc --deny-warn
bash scripts/verify.sh wasm-gc
python scripts/measure.py
```

CI 在 `wasm-gc / wasm / js / native` 上运行严格检查、全部测试、构建与三个示例。
测试包含 4,096 个三属性 singleton-conclusion FD 理论：32,768 个独立闭包/键/cover
比较、8,192 个分解计划、49,152 个二元连接判据与 chase 比较。
此穷举不等于大模式的形式化证明，也没有宣称性能优于其他实现。

## 设计与许可

原创 MIT 库。直接复用 MIT 的 `Zh666-lab/moonconcept@0.1.1` 做 Armstrong
闭包与依赖约简；这里新增关系模式、分解 chase 和元组语义，不重复开发 FCA 核心。
见 [architecture](docs/architecture.md)、[security](docs/security.md)、
[dependency attribution](THIRD-PARTY.md)、[AI use](AI-USE.md) 与
[bounded ecosystem review](docs/competition/duplicate-check.md)。
