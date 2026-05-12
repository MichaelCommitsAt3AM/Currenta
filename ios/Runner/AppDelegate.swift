import Flutter
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let factory = NewsCardAdFactory()
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        self.registrar(forPlugin: "google_mobile_ads")!,
        factoryId: "NewsCardAdFactory",
        nativeAdFactory: factory
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class NewsCardAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: GADNativeAd, customOptions: [AnyHashable : Any]? = nil) -> GADNativeAdView? {
        let adView = GADNativeAdView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        adView.backgroundColor = UIColor(red: 10/255.0, green: 12/255.0, blue: 20/255.0, alpha: 1.0)

        // Media View
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // Headline
        let headlineView = UILabel()
        headlineView.translatesAutoresizingMaskIntoConstraints = false
        headlineView.font = UIFont.boldSystemFont(ofSize: 19)
        headlineView.textColor = .white
        headlineView.numberOfLines = 2
        headlineView.text = nativeAd.headline
        adView.addSubview(headlineView)
        adView.headlineView = headlineView

        // Body
        let bodyView = UILabel()
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.font = UIFont.systemFont(ofSize: 15)
        bodyView.textColor = UIColor(red: 191/255.0, green: 191/255.0, blue: 192/255.0, alpha: 1.0)
        bodyView.numberOfLines = 5
        bodyView.text = nativeAd.body
        adView.addSubview(bodyView)
        adView.bodyView = bodyView

        // Bottom-left AD Branding Badge
        let brandingView = UILabel()
        brandingView.translatesAutoresizingMaskIntoConstraints = false
        brandingView.text = " AD "
        brandingView.font = UIFont.boldSystemFont(ofSize: 12)
        brandingView.textColor = UIColor(red: 1.0, green: 215/255.0, blue: 0.0, alpha: 1.0)
        brandingView.backgroundColor = UIColor(red: 1.0, green: 215/255.0, blue: 0.0, alpha: 0.2)
        brandingView.layer.cornerRadius = 4
        brandingView.clipsToBounds = true
        adView.addSubview(brandingView)

        // Call to action button
        let ctaView = UIButton(type: .system)
        ctaView.translatesAutoresizingMaskIntoConstraints = false
        ctaView.setTitle(nativeAd.callToAction, for: .normal)
        ctaView.setTitleColor(.white, for: .normal)
        ctaView.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        ctaView.backgroundColor = UIColor(red: 108/255.0, green: 99/255.0, blue: 255/255.0, alpha: 1.0)
        ctaView.layer.cornerRadius = 8
        adView.addSubview(ctaView)
        adView.callToActionView = ctaView

        // Constraints setup
        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 60),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 24),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),
            mediaView.heightAnchor.constraint(equalToConstant: 220),

            headlineView.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 24),
            headlineView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 24),
            headlineView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),

            bodyView.topAnchor.constraint(equalTo: headlineView.bottomAnchor, constant: 8),
            bodyView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 24),
            bodyView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),

            brandingView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 24),
            brandingView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -40),

            ctaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),
            ctaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -32),
            ctaView.heightAnchor.constraint(equalToConstant: 48),
            ctaView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        adView.nativeAd = nativeAd
        return adView
    }
}
