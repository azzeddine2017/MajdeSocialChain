# Mejde Network - Universal OpenSSL Loader
# On Android (ring2apk), crypto functions are statically embedded in libmain.so.
# On Windows Desktop, the dynamic library is loaded.

if iswindows()
    try
        loadlib("ring_openssl.dll")
    catch
    done
ok
