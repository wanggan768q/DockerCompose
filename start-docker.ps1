# Docker Compose 启动脚本
# 列出目录下所有yml配置文件，通过数字选择启动

Write-Host "=== Docker Compose 配置文件列表 ===" -ForegroundColor Green
Write-Host ""

# 获取当前目录下所有yml和yaml文件
$ymlFiles = Get-ChildItem -Path . -Filter "*.yml" -File
$yamlFiles = Get-ChildItem -Path . -Filter "*.yaml" -File
$allFiles = @($ymlFiles) + @($yamlFiles)

if ($allFiles.Count -eq 0) {
    Write-Host "当前目录下没有找到yml或yaml配置文件！" -ForegroundColor Red
    exit 1
}

# 显示文件列表
for ($i = 0; $i -lt $allFiles.Count; $i++) {
    Write-Host "[$($i + 1)] $($allFiles[$i].Name)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "请选择要启动的配置文件 (输入数字 1-$($allFiles.Count)):" -ForegroundColor Yellow

# 读取用户输入
$choice = Read-Host

# 验证输入
if (-not ($choice -match '^\d+$') -or [int]$choice -lt 1 -or [int]$choice -gt $allFiles.Count) {
    Write-Host "无效的选择！请输入 1 到 $($allFiles.Count) 之间的数字。" -ForegroundColor Red
    exit 1
}

# 获取选择的文件
$selectedFile = $allFiles[[int]$choice - 1]
Write-Host ""
Write-Host "已选择: $($selectedFile.Name)" -ForegroundColor Green
Write-Host "正在启动 Docker Compose..." -ForegroundColor Yellow

# 启动 Docker Compose
try {
    Write-Host "执行命令: docker compose -f $($selectedFile.Name) up" -ForegroundColor Gray
    Write-Host "正在启动服务，等待 Configuration completed. 消息..." -ForegroundColor Yellow
    Write-Host ""
    
    # 启动容器并监控日志，等待Configuration completed消息
    $configCompleted = $false
    $maxWaitTime = 180  # 最大等待3分钟
    $waitedTime = 0
    
    # 使用jobs来运行docker compose并捕获输出
    $job = Start-Job -ScriptBlock {
        param($configFile)
        docker compose -f $configFile up 2>&1
    } -ArgumentList $selectedFile.Name
    
    while ($waitedTime -lt $maxWaitTime -and -not $configCompleted) {
        # 获取作业输出
        $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
        
        if ($output) {
            # 按行处理输出，避免乱行
            $lines = $output -split "`r`n"
            foreach ($line in $lines) {
                if ($line.Trim() -ne "") {
                    # 检查是否包含Configuration completed消息
                    if ($line -match "Configuration completed\.") {
                        Write-Host "✓ 检测到配置完成消息！" -ForegroundColor Green
                        $configCompleted = $true
                        break
                    }
                    # 过滤掉进度条和下载信息，只显示重要信息
                    if ($line -notmatch "%\s+\[" -and $line -notmatch "kB/s" -and $line -notmatch "min\s+\d+s") {
                        Write-Host $line -ForegroundColor Gray
                    }
                }
            }
            if ($configCompleted) { break }
        }
        
        Start-Sleep 2
        $waitedTime += 2
        
        if ($waitedTime % 10 -eq 0) {
            Write-Host "等待配置完成... ($($waitedTime)s/$($maxWaitTime)s)" -ForegroundColor Yellow
        }
    }
    
    # 停止前台进程，转为后台运行
    Stop-Job -Job $job 2>$null
    Remove-Job -Job $job 2>$null
    
    if ($configCompleted) {
        Write-Host "配置完成，转为后台运行..." -ForegroundColor Green
        $output = docker compose -f $selectedFile.Name up -d 2>&1
        $exitCode = $LASTEXITCODE
        Write-Host "后台启动输出: $output" -ForegroundColor Gray
    } else {
        Write-Host "等待配置完成超时！" -ForegroundColor Red
        $output = docker compose -f $selectedFile.Name up -d 2>&1
        $exitCode = $LASTEXITCODE
    }
    
    if ($exitCode -eq 0) {
        Write-Host "Docker Compose 启动成功！" -ForegroundColor Green
        Write-Host "输出: $output" -ForegroundColor Gray
        
        # 从yml文件中提取容器名称
        $ymlContent = Get-Content $selectedFile.Name -Raw
        if ($ymlContent -match 'container_name:\s*([^\s\r\n]+)') {
            $containerName = $matches[1]
            Write-Host "等待容器完全初始化: $containerName" -ForegroundColor Yellow
            
            # 等待容器完全启动
            $maxWaitTime = 60  # 最大等待60秒
            $waitInterval = 2   # 每2秒检查一次
            $waitedTime = 0
            
            Write-Host "正在检查容器状态..." -ForegroundColor Gray
            
            while ($waitedTime -lt $maxWaitTime) {
                # 检查容器是否存在且正在运行
                $containerStatus = docker inspect -f '{{.State.Status}}' $containerName 2>$null
                
                if ($containerStatus -eq "running") {
                    # 检查容器是否已完全初始化（可以执行命令）
                    $testResult = docker exec $containerName echo "test" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "容器已就绪，正在进入..." -ForegroundColor Green
                        Write-Host ""
                        
                        # 进入容器交互式bash
                        docker exec -it $containerName /bin/bash
                        break
                    }
                }
                
                Write-Host "等待容器启动... ($($waitedTime)s/$($maxWaitTime)s)" -ForegroundColor Gray
                Start-Sleep $waitInterval
                $waitedTime += $waitInterval
            }
            
            if ($waitedTime -ge $maxWaitTime) {
                Write-Host "等待容器启动超时！请检查容器状态。" -ForegroundColor Red
                Write-Host "手动命令: docker exec -it $containerName /bin/bash" -ForegroundColor Yellow
            }
        } else {
            Write-Host "无法从配置文件中获取容器名称" -ForegroundColor Red
            Write-Host "请手动进入容器：" -ForegroundColor Yellow
            Write-Host "docker exec -it <容器名称> /bin/bash" -ForegroundColor Gray
        }
    } else {
        Write-Host "Docker Compose 启动失败！" -ForegroundColor Red
        Write-Host "退出代码: $exitCode" -ForegroundColor Red
        Write-Host "错误信息:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        Write-Host ""
        Write-Host "可能的解决方案:" -ForegroundColor Yellow
        Write-Host "1. 检查Docker是否正在运行" -ForegroundColor Gray
        Write-Host "2. 检查端口是否被占用" -ForegroundColor Gray
        Write-Host "3. 检查环境变量文件(.env)是否存在" -ForegroundColor Gray
        Write-Host "4. 检查配置文件语法是否正确" -ForegroundColor Gray
    }
} catch {
    Write-Host "启动过程中发生异常:" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "请检查:" -ForegroundColor Yellow
    Write-Host "1. Docker Desktop是否已安装并运行" -ForegroundColor Gray
    Write-Host "2. docker-compose命令是否可用" -ForegroundColor Gray
    Write-Host "3. 配置文件路径是否正确" -ForegroundColor Gray
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")