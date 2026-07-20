# JavaPocket 兼容性记录

更新时间：2026-07-19

## 测试环境

- 应用：JavaPocket 1.0.0（build 6）
- 引擎：FreeJ2ME Web / CheerpJ 4.2
- 构建目标：iOS 16.0+
- 标准分辨率：128×160、176×208、176×220、240×320
- 自动化夹具：10 个独立的合成 JAR manifest（不包含第三方游戏内容）

## 自动化结果

`python -m unittest discover -s Tests -v` 会验证以下十组导入元数据、JAR
文件结构、运行时资源、应用标识、Xcode target 隔离和 RMS 目录约定。

| 夹具 | MIDP / CLDC | 分辨率 | JAR 导入 | 元数据 | 运行 |
|---|---|---:|---|---|---|
| Nokia Classic 240 | MIDP-2.0 / CLDC-1.1 | 240×320 | OK | OK | 需真机 JAR |
| Nokia Series 40 | MIDP-2.0 / CLDC-1.1 | 176×208 | OK | OK | 需真机 JAR |
| Sony Ericsson K | MIDP-2.0 / CLDC-1.1 | 176×220 | OK | OK | 需真机 JAR |
| Motorola V | MIDP-1.0 / CLDC-1.0 | 128×160 | OK | OK | 需真机 JAR |
| Folded Manifest | MIDP-2.0 / CLDC-1.1 | 240×320 | OK | OK | 需真机 JAR |
| Manifest Icon | MIDP-2.0 / CLDC-1.1 | 176×220 | OK | OK | 需真机 JAR |
| MIDlet Icon Fallback | MIDP-1.0 / CLDC-1.0 | 128×160 | OK | OK | 需真机 JAR |
| Chinese Metadata | MIDP-2.0 / CLDC-1.1 | 240×320 | OK | OK | 需真机 JAR |
| Landscape Canvas | MIDP-2.0 / CLDC-1.1 | 320×240 | OK | OK | 需真机 JAR |
| Default Canvas | MIDP-1.0 / CLDC-1.0 | 240×320 | OK | OK | 需真机 JAR |

## 商业游戏回归清单

仓库不分发第三方商业游戏。将合法持有的 JAR 通过 Files、分享菜单或
AirDrop 导入后，在真机上按下表逐项记录；当前没有收到这些 JAR，因此不
伪造启动、声音或存档结果。

| 游戏 | 启动 | 声音 | 按键 | RMS | 横竖屏 | 返回游戏库 | 备注 |
|---|---|---|---|---|---|---|---|
| 梦幻三国 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 吞食天地 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| RPG 样本 1 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| RPG 样本 2 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 横版动作样本 1 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 横版动作样本 2 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 赛车样本 1 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 赛车样本 2 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 益智样本 1 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |
| 益智样本 2 | 待测 | 待测 | 待测 | 待测 | 待测 | 待测 | 需要测试 JAR |

## 已知运行要求

- FreeJ2ME 通过 CheerpJ loader 启动，首次运行需要网络。
- RMS 自动保存到 `Documents/Games/<game-id>/save/rms.zip`。
- MIDI 和媒体转码 WASM 已从 ManicEMU v1.9.2 发布包恢复并校验 SHA-256。
- 真实游戏兼容性只以合法 JAR 在 iPhone/iPad 上的结果为准。
