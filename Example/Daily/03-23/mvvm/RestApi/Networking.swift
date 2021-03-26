//
//  Networking.swift
//  LXToolKit_Exam
//
//  Created by LXThyme Jason on 2021/3/24.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import Moya
import RxSwift
import Alamofire
import ObjectMapper

//class OnlineProvider<Target> where Target: Moya.TargetType {
class OnlineProvider<Target> where Target: Moya.TargetType {
//    fileprivate
    let online: Observable<Bool>
//    fileprivate
    let provider: MoyaProvider<Target>

    init(endpointClosure: @escaping MoyaProvider<Target>.EndpointClosure = MoyaProvider<Target>.defaultEndpointMapping,
         requestClosure: @escaping MoyaProvider<Target>.RequestClosure = MoyaProvider<Target>.defaultRequestMapping,
         stubClosure: @escaping MoyaProvider<Target>.StubClosure = MoyaProvider<Target>.neverStub,
         session: Session = MoyaProvider<Target>.defaultAlamofireSession(),
         plugins: [PluginType] = [],
         trackInflights: Bool = false,
         online: Observable<Bool> = connectedToInternet()) {
        self.online = online
        self.provider = MoyaProvider(endpointClosure: endpointClosure, requestClosure: requestClosure, stubClosure: stubClosure, session: session, plugins: plugins, trackInflights: trackInflights)
    }

    func request(_ token: Target) -> Observable<Moya.Response> {
//    func request(_ token: Target, completion: @escaping (_ result: Result<Moya.Response, MoyaError>) -> Void) -> Cancellable {
//        let actualRequest = provider.request(token, completion: completion)
        let actualRequest = provider.rx.request(token)
        return online
//            .ignore(value: false)  // Wait until we're online
            .take(1)        // Take 1 to make sure we only invoke the API once.
            .flatMap { isOnline in // Turn the online state into a network request
                return actualRequest
                    .filterSuccessfulStatusCodes()
//                    .do { response in
//                        dlog("🛠1. onSuccess: ", response)
//                    } afterSuccess: { response in
//                        dlog("🛠2. afterSuccess: ", response)
////                        completion(
//                    } onError: { error in
//                        dlog("🛠1. onError: ", error)
//                        if let error = error as? MoyaError {
//                            switch error {
//                            case .statusCode(let response):
//                                if response.statusCode == 401 {
//                                    // Unauthorized
//        //                                    if AuthManager.shared.hasValidToken {
//        //                                        AuthManager.removeToken()
//        //                                        Application.shared.presentInitialScreen(in: Application.shared.window)
//        //                                    }
//                                }
//                            default: break
//                            }
//                        }
//                    } afterError: { error in
//                        dlog("🛠2. afterError: ", error)
//                    } onSubscribe: {
//                        dlog("🛠3. onSubscribe: ")
//                    } onSubscribed: {
//                        dlog("🛠4. onSubscribed: ")
//                    } onDispose: {
//                        dlog("🛠5. onDispose: ")
//                    }
            }
    }
}

protocol NetworkingType {
    associatedtype T: TargetType, ProductAPIType
    var provider: OnlineProvider<T> { get }

    static func defaultNetworking() -> Self
    static func stubbingNetworking() -> Self
}

struct GithubNetworking: NetworkingType {
    typealias T = XLGithubAPI
    let provider: OnlineProvider<T>

    static func defaultNetworking() -> Self {
        return GithubNetworking(provider: newProvider(plugins))
    }

    static func stubbingNetworking() -> Self {
        return GithubNetworking(provider: OnlineProvider(endpointClosure: endpointsClosure(), requestClosure: GithubNetworking.endpointResolver(), stubClosure: MoyaProvider.immediatelyStub, online: .just(true)))
    }

    func request(_ token: T) -> Observable<Moya.Response> {
        let actualRequest = self.provider.request(token)
        return actualRequest
    }
}
// MARK: - 👀
class XLResponse: NSObject, NSKeyedArchiverDelegate, NSKeyedUnarchiverDelegate, NSCoding {
    let statusCode: Int
    let data: Data?
    let request: URLRequest?
    let response: HTTPURLResponse?
    init(statusCode: Int, data: Data?, request: URLRequest?, response: HTTPURLResponse?) {
        self.statusCode = statusCode
        self.data = data
        self.request = request
        self.response = response
    }
    required init?(coder: NSCoder) {
        self.statusCode = coder.decodeInteger(forKey: "statusCode")
        self.data = coder.decodeObject(forKey: "data") as? Data
        self.request = coder.decodeObject(forKey: "request") as? URLRequest
        self.response = coder.decodeObject(forKey: "response") as? HTTPURLResponse
    }
    func encode(with coder: NSCoder) {
        coder.encode(statusCode, forKey: "statusCode")
        coder.encode(data, forKey: "data")
        coder.encode(request, forKey: "request")
        coder.encode(response, forKey: "response")
    }
}
extension GithubNetworking {
    func request3(_ token: T, fromCache: Bool = false, needCache: Bool = true) -> Observable<Result<Moya.Response, ApiError>> {
        let actualRequest = request2(token, fromCache: fromCache, needCache: needCache)
        return provider.online
//            .ignore(value: false)
            .take(1)
            .flatMap { isOnline -> Observable<Result<Moya.Response, ApiError>> in
                Logger.debug("isOnline: \(isOnline)")
                return actualRequest
            }
    }
    func request2(_ token: T, fromCache: Bool = false, needCache: Bool = true) -> Observable<Result<Moya.Response, ApiError>> {
//        let actualRequest = self.provider.request(token)
//        return actualRequest
        return Observable.create { observer -> Disposable in
            let cachedkey = token.cachedKey
            if fromCache,
               let data = GlobalConfig.yyCache?.object(forKey: cachedkey) as? XLResponse {
                let cachedResponse = Response(statusCode: data.statusCode, data: data.data ?? Data(), request: data.request, response: data.response)
                observer.onNext(.success(cachedResponse))
                observer.onCompleted()
            }
            let cancelableToken = self.provider.provider.request(token) { result in
                switch result {
                    case .success(let response):
                        if needCache {
                            let obj = XLResponse(statusCode: response.statusCode, data: response.data, request: response.request, response: response.response)
                            GlobalConfig.yyCache?.setObject(obj, forKey: cachedkey, with: nil)
                        }
                        observer.onNext(.success(response))
                    case .failure(let error):
                        switch error {
                            case .imageMapping(let response),
                                 .jsonMapping(let response),
                                 .stringMapping(let response):
                                observer.onNext(.failure(.serializeError(response: response, error: nil)))
                            case .encodableMapping(let error):
                                observer.onNext(.failure(.serializeError(response: nil, error: error)))
                            case .statusCode(let response):
                                observer.onNext(.failure(.invalidStatusCode(statusCode: response.statusCode, msg: "", tips: "")))
                            case .objectMapping(let error, let response):
                                observer.onNext(.failure(.serializeError(response: response, error: error)))
                            case .underlying(let error, let response):
                                observer.onNext(.failure(.serializeError(response: response, error: error)))
                            case .requestMapping(let string):
                                observer.onNext(.failure(.serializeError(response: nil, error: NSError(domain: string, code: 999, userInfo: nil) as Error)))
                            case .parameterEncoding(let error):
                                observer.onNext(.failure(.serializeError(response: nil, error: error)))
                        }
                }
                observer.onCompleted()
            }
            return Disposables.create {
                cancelableToken.cancel()
            }
        }
    }
}

extension NetworkingType {
    static func endpointsClosure<T>(_ xAccessToken: String? = nil) -> (T) -> Endpoint where T: TargetType, T: ProductAPIType {
        return { target in
            let endpoint = MoyaProvider.defaultEndpointMapping(for: target)

            // Sign all non-XApp, non-XAuth token requests
            return endpoint
        }
    }

    static func APIKeysBasedStubBehaviour<T>(_: T) -> Moya.StubBehavior {
        return .never
    }

    static var plugins: [PluginType] {
        var plugins: [PluginType] = []
        if GlobalConfig.Network.loggingEnabled == true {
            plugins.append(NetworkLoggerPlugin())
        }
        return plugins
    }

    // (Endpoint<Target>, NSURLRequest -> Void) -> Void
    static func endpointResolver() -> MoyaProvider<T>.RequestClosure {
        return { (endpoint, closure) in
            do {
                var request = try endpoint.urlRequest() // endpoint.urlRequest
                request.httpShouldHandleCookies = false
                closure(.success(request))
            } catch {
                Logger.error("🛠endpointResolver: \(error.localizedDescription)")
            }
        }
    }
}

private func newProvider<T>(_ plugins: [PluginType], xAccessToken: String? = nil) -> OnlineProvider<T> where T: ProductAPIType {
    return OnlineProvider(endpointClosure: GithubNetworking.endpointsClosure(xAccessToken),
                          requestClosure: GithubNetworking.endpointResolver(),
                          stubClosure: GithubNetworking.APIKeysBasedStubBehaviour,
                          plugins: plugins)
}

// MARK: - Provider support

func stubbedResponse(_ filename: String) -> Data! {
    @objc class TestClass: NSObject { }

    let bundle = Bundle(for: TestClass.self)
    let path = bundle.path(forResource: filename, ofType: "json")
    return (try? Data(contentsOf: URL(fileURLWithPath: path!)))
}

private extension String {
    var URLEscapedString: String {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)!
    }
}

func url(_ route: TargetType) -> String {
    return route.baseURL.appendingPathComponent(route.path).absoluteString
}
