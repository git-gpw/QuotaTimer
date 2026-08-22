cask "quotatimer" do
  version "0.1.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/gabriel-p-wood/QuotaTimer/releases/download/v#{version}/QuotaTimer-#{version}.dmg"
  name "QuotaTimer"
  desc "Menu bar app for tracking LLM usage quotas and countdown timers"
  homepage "https://github.com/gabriel-p-wood/QuotaTimer"

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "QuotaTimer.app"

  zap trash: [
    "~/Library/Preferences/com.gpw.QuotaTimer.plist",
    "~/Library/Caches/com.gpw.QuotaTimer",
    "~/Library/LaunchAgents/com.quotatimer.launcher.plist",
  ]
end
