# Codex + Blender 自动建模工作区

## 项目用途

本工作区用于把文字需求或参考资料整理为可审查的 `bpy` 脚本，再通过 Blender 后台运行生成可复现的三维场景、预览图和交换文件。脚本生成的资产应能由脚本重新构建；人工编辑的资产仍需单独保留。

## 已验证环境

截至 2026-07-10，本机已实际验证：Blender 5.1.2、Apple M1 Pro、32 GB 内存。验证命令为 `"/Applications/Blender.app/Contents/MacOS/Blender" --version`。版本或设备变化后应重新验证，不要仅依据本文判断环境仍然可用。

## 按需目录约定

以下目录目前尚未创建；仅在任务需要时按需创建：

- `scripts/`：存放经检查、可重复执行的 `bpy` Python 脚本。
- `references/`：存放图片、尺寸图、材质说明等输入参考，不作为生成结果。
- `models/`：存放 Blender 工程文件（`.blend`）。
- `renders/`：存放用于视觉检查的预览图或最终渲染图。
- `exports/`：存放供其他软件使用的交换文件，如 `.glb`、`.fbx`、`.obj` 或 `.stl`。

## 工作流程

1. 提供文字需求、尺寸和参考资料，明确输出格式。
2. 在 `scripts/` 编写并检查 `bpy` 脚本，例如 `create_model.py`。
3. 使用后台模式运行 Blender；检查日志、Python 异常和进程退出码。
4. 确认 `models/`、`renders/` 或 `exports/` 中预期文件存在且非空。
5. 打开预览图进行视觉检查；必要时调整脚本并重新生成，再交付 `.blend` 或交换文件。

可复制的后台命令：

```sh
"/Applications/Blender.app/Contents/MacOS/Blender" --background --python "/Users/youzhi/workspace/blender space/scripts/create_model.py"
```

## 任务输入清单

- 对象：要创建什么，以及关键组成部分。
- 尺寸：单位、整体尺寸、比例和容差。
- 风格：写实、低多边形、产品可视化等。
- 材质：颜色、粗糙度、金属度、透明度或纹理要求。
- 参考资料：参考图、草图、尺寸图及其用途。
- 输出格式：`.blend`、预览图以及所需的 `.glb`、`.fbx`、`.obj` 或 `.stl`。

## 能力边界

Codex + `bpy` 适合把明确规则、几何参数和可描述步骤转成可重复执行的建模脚本。它不等同于 Hyper3D 等图像转 3D 生成服务，也不承诺仅凭一张图片直接得到同等结果。图像驱动的复杂有机模型通常需要专用模型、外部服务或人工修整。

## 故障排查

- 找不到 Blender 可执行文件：确认 `/Applications/Blender.app/Contents/MacOS/Blender` 存在；若安装位置不同，修改命令中的完整路径，并运行 `--version` 复核。
- Python 异常或非零退出码：保留完整日志，定位首个 traceback；修正脚本后重跑。即使日志出现部分成功信息，也不能忽略非零退出码。
- 路径含空格：始终用双引号包住 Blender、脚本和输出的完整路径；不要拆开 `blender space`。
- 渲染引擎或设备不可用：检查脚本选择的引擎与设备是否在当前 Blender 中可用；必要时改用已验证的引擎或 CPU，并在重跑前明确记录降级。
- 未生成输出：先检查退出码和日志，再核对脚本中的绝对输出路径、目标目录是否已按需创建，以及预期文件是否存在且非空。没有输出文件时不得宣称任务成功。
