platform :ios, '15.0'

project 'com.mattiaponcini.project.xcodeproj'

target 'com.mattiaponcini.project' do
  use_frameworks!

  # Firebase
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'FirebaseFirestoreSwift'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'        # push notification (FCM ↔ APNs bridge)

  # Aggiungi qui altre pod se ti servono, esempi:
  # pod 'Firebase/Crashlytics'      # crash reporting
  # pod 'Firebase/Database'         # Realtime Database (alternativa a Firestore)
  # pod 'Firebase/RemoteConfig'     # config dinamica
  # pod 'Firebase/Functions'        # Cloud Functions

end

# Fix: BoringSSL-GRPC ships con il flag '-GCC_WARN_INHIBIT_ALL_WARNINGS'
# che clang interpreta come '-G ...' — non supportato su arm64 iOS Simulator
# (Apple Silicon). Lo rimuoviamo dai COMPILER_FLAGS dei file source del pod,
# e allineiamo l'IPHONEOS_DEPLOYMENT_TARGET dei pod a quello dell'app per
# evitare warning sul vecchio target ios10.0.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    # Rimuovi il flag bacato da BoringSSL-GRPC
    if target.respond_to?(:source_build_phase) && target.source_build_phase
      target.source_build_phase.files.each do |file|
        next unless file.settings && file.settings['COMPILER_FLAGS']
        flags = file.settings['COMPILER_FLAGS'].split
        flags.reject! { |f| f == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
        file.settings['COMPILER_FLAGS'] = flags.join(' ')
      end
    end

    # Allinea il deployment target a quello dell'app
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end

  # Fix: basic_seq.h (presente sia in gRPC-Core che in gRPC-C++) usa
  # `Traits::template CallSeqFactory(...)` che Clang recente rifiuta
  # ("template argument list expected after a name prefixed by template").
  # Gli argomenti template sono deducibili, basta togliere la keyword.
  ['gRPC-Core', 'gRPC-C++'].each do |pod_name|
    path = File.join(installer.sandbox.root, pod_name, 'src', 'core', 'lib', 'promise', 'detail', 'basic_seq.h')
    next unless File.exist?(path)
    contents = File.read(path)
    patched = contents.gsub('Traits::template CallSeqFactory(', 'Traits::CallSeqFactory(')
    if patched != contents
      File.write(path, patched)
      puts "Patched #{pod_name}/.../basic_seq.h (removed `template` keyword)"
    end
  end
end
