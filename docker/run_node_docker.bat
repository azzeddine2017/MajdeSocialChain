@echo off
echo ========================================================================
echo        MEJDE NETWORK - MOTHER NODE DOCKER DEPLOYMENT
echo ========================================================================
echo.
echo [*] Building and launching Mejde Mother Node container...
docker compose up -d --build
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Mejde Mother Node is now running!
    echo.
    echo   - Web Console Dashboard: http://localhost:8545/
    echo   - P2P Status Telemetry:  http://localhost:8545/p2p/status
    echo   - Database Storage:      ./data/social_mother.db
    echo.
    echo [TIP] To view live logs: docker logs -f mejde-mother-node
) else (
    echo [ERROR] Docker build/run failed. Ensure Docker Desktop is running.
)
pause
