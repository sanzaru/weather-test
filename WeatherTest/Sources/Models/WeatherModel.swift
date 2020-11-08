//
//  WeatherViewModel.swift
//  WeatherTest
//
//  Created by Martin Albrecht on 14.10.20.
//

import Foundation
import RxSwift
import RxRelay


struct OpenWeatherMapJSON: Decodable {
    struct ListDataWeather: Decodable {
        var id: Int
        var main: String
        var description: String
    }
    
    struct ListMainData: Decodable {
        var temp: Double
        var tempFelt: Double
        var tempMin: Double
        var tempMax: Double
        var pressure: Double
        var seaLevel: Double
        var grndLevel: Double
        var humidity: Double
        
        private enum CodingKeys: String, CodingKey {
            case temp, pressure, humidity, tempMin, tempMax, seaLevel, grndLevel
            case tempFelt = "feelsLike"
        }
    }
    
    struct ListData: Decodable {
        var dtTxt: String
        var visibility: Int
        var pop: Double
        var main: ListMainData
        var weather: [ListDataWeather]
        var clouds: Dictionary<String, Int>
        var wind: Dictionary<String, Double>
        var rain: Dictionary<String, Double>?
        var sys: Dictionary<String, String>
    }
    
    struct CityData: Decodable {
        var id: Int
        var name: String
        var coord: Dictionary<String, Double>
        var country: String
        var population: Int
        var timezone: Int
        var sunrise: Int
        var sunset: Int
    }
    
    var list: [ListData]
    var city: CityData
}



struct OpenweatherMapForecastDay {
    var date: Date
    var main: OpenWeatherMapJSON.ListMainData
    var visibility: Int = 0
    var rainProbability: Double = 0
    var clouds: Dictionary<String, Int>
    var wind: Dictionary<String, Double>
    var rain: Dictionary<String, Double>?
    var sys: Dictionary<String, String>
    var weather: OpenWeatherMapJSON.ListDataWeather
    var city: OpenWeatherMapJSON.CityData
}



class WeatherModel {
    var selectedForecast: PublishSubject<[OpenweatherMapForecastDay]> = PublishSubject<[OpenweatherMapForecastDay]>()
    var forcastDayDates: PublishSubject<[Date]> = PublishSubject<[Date]>()
    var forcastCity: PublishSubject<String> = PublishSubject<String>()
    
    private var forecastData: [OpenweatherMapForecastDay] = [OpenweatherMapForecastDay]()
    
    /// Set selected forecast data
    /// - Parameter to: The date to select data for
    func setSelected(to: Date) {
        let items = forecastData.filter {
            Calendar.current.isDate($0.date, inSameDayAs: to)
        }
        
        selectedForecast.on(.next(items))
    }
    
    /// Fetch OpenWeatherMap data
    /// - Parameter city: The city name to fetch data for
    /// - Returns: An boolean that defines the state of fetching (false on error)
    func fetch(for city: String) -> Observable<Bool> {
        var fetchUrl: URL {
            var urlComponents = URLComponents(string: AppGlobals.apiBaseUrl + "/forecast")!
            var queryParams: [URLQueryItem] {
                return [
                    .init(name: "q", value: city),
                    .init(name: "lang", value: "de"),
                    .init(name: "units", value: "metric"),
                    .init(name: "appid", value: AppGlobals.apiKey)
                ]
            }
            urlComponents.queryItems = queryParams
            return urlComponents.url!
        }
        
        return Observable.create { observer in
            var req = URLRequest(url: fetchUrl)
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: req) { (data, response, error) in
                guard let data = data else {
                    observer.onNext(false)
                    observer.onError("No data" as! Error)
                    return
                }
                
                DispatchQueue.main.async {
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let response = try decoder.decode(OpenWeatherMapJSON.self, from: data)
                    
                        // Parse data
                        self.forecastData = self.parseForecastData(data: response)
                        self.forcastDayDates.on(.next(self.parseForecastDates()))
                        self.forcastCity.on(.next(response.city.name))
                        self.setSelected(to: self.forecastData.first!.date)
                        
                        observer.onNext(true)
                        observer.onCompleted()
                    } catch let err {
                        dump(err)
                        observer.onNext(false)
                        observer.onError(err)
                    }
                }
            }
            
            task.resume()
            return Disposables.create { task.cancel() }
        }
    }
    
    // MARK: - Private methods
    
    /// Parse forecast data for dates and return them in an array
    /// Duplicate dates will be discarded
    /// - Returns: Array of unique dates
    private func parseForecastDates() -> [Date] {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd"
        
        var dates = [Date]()
        for item in forecastData {
            if let shortDate = formatter.date(from: formatter.string(from: item.date)) {
                if !dates.contains(shortDate) {
                    dates.append(shortDate)
                }
            }
        }
        
        return dates
    }
    
    /// Parse forcast data into our data model
    /// - Parameter data: The forecast data
    /// - Returns: Array with forecast data model objects
    private func parseForecastData(data: OpenWeatherMapJSON) -> [OpenweatherMapForecastDay] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "de_DE_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return data.list.map { (item) -> OpenweatherMapForecastDay in
            OpenweatherMapForecastDay(
                date: dateFormatter.date(from: item.dtTxt)!,
                main: item.main,
                visibility: item.visibility,
                rainProbability: item.pop,
                clouds: item.clouds,
                wind: item.wind,
                rain: item.rain,
                sys: item.sys,
                weather: item.weather.first!,
                city: data.city
            )
        }
    }
}
