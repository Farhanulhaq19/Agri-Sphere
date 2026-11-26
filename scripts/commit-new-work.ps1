# Run from the project root:  powershell -ExecutionPolicy Bypass -File scripts\commit-new-work.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$trail = "`n`nCo-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`nClaude-Session: https://claude.ai/code/session_013sGYs7ZWGdTrUgWeJLt2u6"

Write-Host "1/3 flutter analyze..." -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host "Fix analyzer errors first, then re-run." -ForegroundColor Red; exit 1 }

git checkout develop
git pull origin develop

function Ship($branch, $steps) {
  git checkout -B $branch develop
  foreach ($s in $steps) {
    git add -- $s.paths
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { git commit -m ($s.msg + $trail) }
  }
  git push -u origin $branch --force-with-lease
}

Ship 'feature/auth-module' @(
  @{ paths=@('backend/models/User.js','backend/models/ResetOtp.js','backend/utils/rateLimit.js','backend/utils/identity.js'); msg='feat(auth-api): multi-role users, reset codes and rate limiting' },
  @{ paths=@('backend/routes/auth.js','backend/routes/modules/profile.js'); msg='feat(auth-api): forgot/reset/change password, switch/add/remove role' },
  @{ paths=@('lib/core/services/api_service.dart','lib/core/utils/validators.dart','lib/modules/module_01_auth/roles.dart','lib/modules/module_01_auth/session_helper.dart'); msg='feat(auth-app): session, remember-me and password APIs in client' },
  @{ paths=@('lib/modules/module_01_auth/widgets','lib/core/widgets/app_extras.dart'); msg='feat(auth-app): password strength meter, account button, shared widgets' },
  @{ paths=@('lib/modules/module_01_auth/screens','lib/main.dart'); msg='feat(auth-app): multi-role signup/login, forgot & reset password, account page' },
  @{ paths=@('lib/modules/module_06_expert','lib/modules/module_07_supplier','lib/modules/module_08_admin','lib/modules/module_02_dashboard'); msg='feat(auth-app): account entry points in every role home' }
)

Ship 'feature/machinery-module' @(
  @{ paths=@('backend/models/machinery.js','backend/utils/seedFleet.js'); msg='feat(machinery-api): machine, technician, booking and maintenance models' },
  @{ paths=@('backend/routes/modules/machinery.js','backend/routes/agri.js'); msg='feat(machinery-api): rent/buy booking, technician hours pricing, owner tools' },
  @{ paths=@('lib/modules/module_09_machinery'); msg='feat(machinery-app): owner console and renter booking flow' }
)

Ship 'feature/warehouse-module' @(
  @{ paths=@('backend/models/warehouse.js'); msg='feat(warehouse-api): warehouse, labour and storage booking models' },
  @{ paths=@('backend/routes/modules/warehouse.js'); msg='feat(warehouse-api): storage requests, readings, tasks and payments' },
  @{ paths=@('lib/modules/module_10_warehouse'); msg='feat(warehouse-app): owner console and farmer storage flow' }
)

Ship 'feature/marketplace-offers' @(
  @{ paths=@('backend/models/offer.js','backend/routes/modules/offers.js'); msg='feat(offers-api): offers, counter-offers and order on accept' },
  @{ paths=@('lib/modules/module_04_marketplace'); msg='feat(offers-app): make offer sheet and negotiation screen' }
)

git checkout develop
foreach ($b in 'feature/auth-module','feature/machinery-module','feature/warehouse-module','feature/marketplace-offers') {
  git merge --no-ff --no-edit -m "Merge $b into develop$trail" $b
}
git push origin develop
Write-Host "`nDone. Open the PR develop -> main:" -ForegroundColor Green
Write-Host "https://github.com/Farhanulhaq19/Agri-Sphere/compare/main...develop?expand=1"
