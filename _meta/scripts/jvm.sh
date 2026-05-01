echo "/usr/lib/jvm/java-21-openjdk-amd64/lib/server" | sudo tee /etc/ld.so.conf.d/java-jvm.conf
sudo ldconfig

# if (interactive()) {
#   tryCatch(
#     {
#       jvm_path <- Sys.getenv("LIBJVM_PATH", unset = NA)
#       if (is.na(jvm_path)) {
#         jvm_path <- system("find /usr/lib -name libjvm.so", intern = TRUE)[1]
#       }
#       if (!is.na(jvm_path) && nzchar(jvm_path)) dyn.load(jvm_path)
#     },
#     error = \(e) message("Note: JVM not loaded — ", conditionMessage(e))
#   )
# }
