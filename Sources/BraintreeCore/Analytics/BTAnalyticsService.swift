import Foundation

class BTAnalyticsService {

    // MARK: - Internal Properties

    // swiftlint:disable force_unwrapping
    /// The FPTI URL to post all analytic events.
    static let url = URL(string: "https://api.paypal.com")!
    // swiftlint:enable force_unwrapping

    /// The HTTP client for communication with the analytics service endpoint. Exposed for testing.
    var http: BTHTTP
    
    /// Exposed for testing only
    var shouldBypassTimerQueue = false

    // MARK: - Private Properties
    
    private static let events = BTAnalyticsEventsStorage()
    
    /// Amount of time, in seconds, between batch API requests sent to FPTI
    private static let timeInterval = 15
    
    private let timer = RepeatingTimer(timeInterval: timeInterval)
    
    private let authorization: ClientAuthorization
    private let configuration: BTConfiguration
    private let metadata: BTClientMetadata
    
    // MARK: - Initializer
    
    init(authorization: ClientAuthorization, configuration: BTConfiguration, metadata: BTClientMetadata) {
        self.authorization = authorization
        self.configuration = configuration
        self.http = BTHTTP(authorization: authorization, customBaseURL: Self.url)
        self.metadata = metadata
        
        timer.eventHandler = { [weak self] in
            print("✅ ⏲️ Timer handler fired")
            guard let self else { return }
            Task {
                await self.sendQueuedAnalyticsEvents()
            }
        }
        timer.resume()
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("✅ 🆕 BTAnalyticsService \(address)")
    }

    // MARK: - Deinit

    deinit {
        let address = Unmanaged.passUnretained(self).toOpaque()
        print("✅ 🧽 BTAnalyticsService deinit \(address)")
        timer.suspend()
    }

    // MARK: - Internal Methods
    
    /// Sends analytics event to https://api.paypal.com/v1/tracking/batch/events/ via a background task.
    /// - Parameters:
    ///   - eventName: Name of analytic event.
    ///   - correlationID: Optional. CorrelationID associated with the checkout session.
    ///   - endpoint: Optional. The endpoint of the API request send during networking requests.
    ///   - endTime: Optional. The end time of the roundtrip networking request.
    ///   - errorDescription: Optional. Full error description returned to merchant.
    ///   - isVaultRequest: Optional. If the Venmo or PayPal request is being vaulted.
    ///   - linkType: Optional. The type of link the SDK will be handling, currently deeplink or universal.
    ///   - payPalContextID: Optional. PayPal Context ID associated with the checkout session.
    ///   - startTime: Optional. The start time of the networking request.
    func sendAnalyticsEvent(
        _ eventName: String,
        connectionStartTime: Int? = nil,
        correlationID: String? = nil,
        endpoint: String? = nil,
        endTime: Int? = nil,
        errorDescription: String? = nil,
        isVaultRequest: Bool? = nil,
        linkType: String? = nil,
        payPalContextID: String? = nil,
        requestStartTime: Int? = nil,
        startTime: Int? = nil
    ) {
        Task(priority: .background) {
            await performEventRequest(
                eventName,
                connectionStartTime: connectionStartTime,
                correlationID: correlationID,
                endpoint: endpoint,
                endTime: endTime,
                errorDescription: errorDescription,
                isVaultRequest: isVaultRequest,
                linkType: linkType,
                payPalContextID: payPalContextID,
                requestStartTime: requestStartTime,
                startTime: startTime
            )
        }
    }
    
    /// Exposed to be able to execute this function synchronously in unit tests
    func performEventRequest(
        _ eventName: String,
        connectionStartTime: Int? = nil,
        correlationID: String? = nil,
        endpoint: String? = nil,
        endTime: Int? = nil,
        errorDescription: String? = nil,
        isVaultRequest: Bool? = nil,
        linkType: String? = nil,
        payPalContextID: String? = nil,
        requestStartTime: Int? = nil,
        startTime: Int? = nil
    ) async {
        let timestampInMilliseconds = Date().utcTimestampMilliseconds
        let event = FPTIBatchData.Event(
            connectionStartTime: connectionStartTime,
            correlationID: correlationID,
            endpoint: endpoint,
            endTime: endTime,
            errorDescription: errorDescription,
            eventName: eventName,
            isVaultRequest: isVaultRequest,
            linkType: linkType,
            payPalContextID: payPalContextID,
            requestStartTime: requestStartTime,
            startTime: startTime,
            timestamp: String(timestampInMilliseconds)
        )

        await BTAnalyticsService.events.append(event)
        
        if shouldBypassTimerQueue {
            await self.sendQueuedAnalyticsEvents()
        }
    }

    // MARK: - Helpers

    func sendQueuedAnalyticsEvents() async {
//        if await !BTAnalyticsService.events.isEmpty {
            print("✅ 🎤 Sending events")
            let postParameters = await createAnalyticsEvent(sessionID: metadata.sessionID, events: Self.events.allValues)
            http.post("v1/tracking/batch/events", parameters: postParameters) { _, _, _ in }
//            await Self.events.removeAll()
//        }
    }

    /// Constructs POST params to be sent to FPTI
    func createAnalyticsEvent(sessionID: String, events: [FPTIBatchData.Event]) -> Codable {
        let batchMetadata = FPTIBatchData.Metadata(
            authorizationFingerprint: authorization.type == .clientToken ? authorization.bearer : nil,
            environment: configuration.fptiEnvironment,
            integrationType: metadata.integration.stringValue,
            merchantID: configuration.merchantID,
            sessionID: sessionID,
            tokenizationKey: authorization.type == .tokenizationKey ? authorization.originalValue : nil
        )
        
        return FPTIBatchData(metadata: batchMetadata, events: events)
    }
}
