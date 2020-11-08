//
//  ViewController.swift
//  WeatherTest
//
//  Created by Martin Albrecht on 14.10.20.
//

import UIKit
import RxSwift
import RxCocoa



class WeatherDataCell: UITableViewCell {
    @IBOutlet weak var labelTemp: UILabel!
    @IBOutlet weak var labelTempFelt: UILabel!
    @IBOutlet weak var labelTempMinMax: UILabel!
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var labelDescription: UILabel!
    @IBOutlet weak var labelHumidity: UILabel!
    @IBOutlet weak var labelVisibility: UILabel!
    @IBOutlet weak var labelRainProbability: UILabel!
    @IBOutlet weak var labelPressure: UILabel!
    
    private let dateFormatter = DateFormatter()
    
    func setup(element: OpenweatherMapForecastDay) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.dateFormat = "HH:mm"
        
        labelDate.text = "\(dateFormatter.string(from: element.date)) Uhr"
        labelDescription.text = "\(element.weather.description)"
        labelTemp.text = "\(element.main.temp) °C"
        labelTempFelt.text = "\(element.main.tempFelt) °C"
        labelTempMinMax.text = "\(element.main.tempMax) / \(element.main.tempMin) °C"
        labelHumidity.text = "\(element.main.humidity) %"
        labelVisibility.text = "~ \(element.visibility) m"
        labelRainProbability.text = "\(element.rainProbability) %"
        labelPressure.text = "\(element.main.pressure) hPa"
    }
}



class ViewController: UIViewController, UITableViewDelegate {
    @IBOutlet weak var daySelectSegmentControl: UISegmentedControl!
    @IBOutlet weak var detailsDataTableView: UITableView!
    @IBOutlet weak var labelCityName: UILabel!
    @IBOutlet var loadingView: UIView!
    
    private let disposeBag = DisposeBag()
    private let weatherViewModel = WeatherModel()
    private var daySelectDates = [Date]()
    private var dateChanged = PublishSubject<Date>()
    
    private var cityName = "Berlin"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detailsDataTableView.delegate = self
                        
        view.addSubview(loadingView)        
        
        // Refresh control
        detailsDataTableView.refreshControl = UIRefreshControl()
        detailsDataTableView.refreshControl?.addTarget(self, action:
                                              #selector(handleRefreshControl),
                                              for: .valueChanged)
        
        // MARK: - Binding
        weatherViewModel.fetch(for: cityName)
            .subscribe(
                onNext: { data in
                    if data {
                        UIView.animate(withDuration: 1, animations: {self.loadingView.alpha = 0} ) { _ in
                            self.loadingView.isHidden = true
                        }
                    }
                },
                onError: { err in
                    fatalError(err.localizedDescription)
                }
            )
            .disposed(by: disposeBag)
        
        weatherViewModel.forcastDayDates.subscribe(
            onNext: { data in
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM."
                
                self.daySelectDates = data
                
                for i in 0..<data.count {                    
                    if i > self.daySelectSegmentControl.numberOfSegments-1 {
                        self.daySelectSegmentControl.insertSegment(
                            withTitle: formatter.string(from: data[i]),
                            at: i,
                            animated: true)
                    } else {
                        self.daySelectSegmentControl.setTitle(formatter.string(from: data[i]), forSegmentAt: i)
                    }
                }
            },
            onError: { err in
                fatalError(err.localizedDescription)
            }
        )
        .disposed(by: disposeBag)
        
        
        weatherViewModel.forcastCity.bind(to: self.labelCityName.rx.text).disposed(by: disposeBag)
        
        weatherViewModel.selectedForecast.bind(
            to: detailsDataTableView.rx.items(cellIdentifier: "WeatherDataCell", cellType: WeatherDataCell.self)
        ) { (row, element, cell) in
            cell.setup(element: element)
        }
        .disposed(by: disposeBag)
        
        
        // MARK: - Day select
        daySelectSegmentControl.rx.selectedSegmentIndex.subscribe (
            onNext: { index in
                if index < self.daySelectDates.count {
                    self.dateChanged.on(.next(self.daySelectDates[index]))
                    self.detailsDataTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: UITableView.ScrollPosition.top, animated: true)
                }
            },
            onError: { err in
                fatalError(err.localizedDescription)
            }
        )
        .disposed(by: disposeBag)
        
        dateChanged.subscribe(
            onNext: { date in
                self.weatherViewModel.setSelected(to: date)
            },
            onError: { err in
                fatalError(err.localizedDescription)
            }
        )
        .disposed(by: disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        loadingView.frame = view.bounds
    }
    
    // MARK: - Private methods
    @objc private func handleRefreshControl() {
        self.weatherViewModel.fetch(for: cityName).subscribe(onNext: { _ in
            self.daySelectSegmentControl.selectedSegmentIndex = 0
            self.detailsDataTableView.refreshControl?.endRefreshing()
        })
        .disposed(by: disposeBag)
    }
}

