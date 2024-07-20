import UIKit
import HealthKit

class ViewController: UIViewController {
    
    let healthStore = HKHealthStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        requestHealthKitAuthorization()
    }
    
    func requestHealthKitAuthorization() {
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if success {
                self.fetchHealthData()
            } else {
                print("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }
    
    func fetchHealthData() {
        let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        var interval = DateComponents()
        interval.day = 1
        
        let query = HKStatisticsCollectionQuery(quantityType: stepCountType,
                                                quantitySamplePredicate: nil,
                                                options: .cumulativeSum,
                                                anchorDate: startDate,
                                                intervalComponents: interval)
        
        query.initialResultsHandler = { query, results, error in
            guard let statsCollection = results else {
                print("Failed to fetch steps: \(String(describing: error))")
                return
            }
            
            var healthData: [[String: Any]] = []
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            statsCollection.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                if let quantity = statistics.sumQuantity() {
                    let steps = quantity.doubleValue(for: HKUnit.count())
                    let data: [String: Any] = [
                        "type": "stepCount",
                        "startDate": dateFormatter.string(from: statistics.startDate),
                        "endDate": dateFormatter.string(from: statistics.endDate),
                        "value": steps
                    ]
                    healthData.append(data)
                }
            }
            
            // Send data to server
            self.sendDataToServer(healthData)
        }
        
        healthStore.execute(query)
    }

    func sendDataToServer(_ healthData: [[String: Any]]) {
        guard let url = URL(string: "https://fitnesstrackeren-78d4b8d493db.herokuapp.com/api/health-data") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: healthData, options: [])
            request.httpBody = jsonData

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send data: \(error)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    print("Server error")
                    return
                }

                print("Data sent successfully")
            }

            task.resume()
        } catch {
            print("Failed to serialize JSON: \(error)")
        }
    }

}




