# ==============================================================================
# Mejde Network - Brand Logo Installer
# Copies the brand image to all project public assets and installer folders
# ==============================================================================

load "stdlib.ring"

cSrc = "C:/Users/Azzeddine/.gemini/antigravity-ide/brain/12d44af2-4ec7-47c3-a4c6-3f8bd48b55ba/.user_uploaded/media_1790553660025.png"
if not fexists(cSrc) {
    # Check current directory
    if fexists("public/logo.png") {
        cSrc = "public/logo.png"
    }
}

if fexists(cSrc) {
    cData = read(cSrc)
    if len(cData) > 0 {
        # Ensure directories exist
        if not fexists("public") { system("mkdir public") }
        if not fexists("frontend/public") { system("mkdir frontend\\public") }
        if not fexists("installer") { system("mkdir installer") }
        if not fexists("android/assets") { system("mkdir android\\assets") }

        write("public/logo.png", cData)
        write("public/icon.png", cData)
        write("frontend/public/logo.png", cData)
        write("frontend/public/favicon.png", cData)
        write("installer/logo.png", cData)
        write("android/assets/icon.png", cData)
        see "[Brand] Logo successfully installed to all assets directories! (" + string(len(cData)) + " bytes)" + nl
    }
else
    see "[Warning] Source brand logo not found: " + cSrc + nl
}
