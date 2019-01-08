//
//  ViewController.swift
//  PlacesApp
//
//  Created by zombietux on 28/11/2018.
//  Copyright © 2018 zombietux. All rights reserved.
//

import UIKit
import MapKit
import QuadratTouch

class PlacesViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var mapView:MKMapView?
    @IBOutlet weak var tableView:UITableView?
    
    var locationManager:CLLocationManager?
    
    var client:Client?
    var session:Session?
    
    var places:[[String:Any]] = [[String:Any]]()
    
    var hasFinishedQuery:Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        
        if(locationManager != nil) {
            locationManager!.requestAlwaysAuthorization()
            
            locationManager!.delegate = self
            locationManager!.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager!.distanceFilter = 50.0

            locationManager!.startUpdatingLocation()
        }
        
        if(mapView != nil) {
            mapView!.delegate = self
        }
        
        if(tableView != nil) {
            tableView!.delegate = self
            tableView!.dataSource = self
        }
        
        setupFoursquare()
    }
    
    func setupFoursquare() {
        client = Client(clientID: "...", clientSecret: "...", redirectURL: "")
        
        if(client != nil) {
            var configuration = Configuration(client: client!)
            
            Session.setupSharedSessionWithConfiguration(configuration)
        }
        
        session = Session.sharedSession()
    }
    
    func queryFoursquare(location:CLLocation)
    {
        if session == nil || hasFinishedQuery == false
        {
            return
        }
        
        places.removeAll()
        
        var parameters = location.parameters()
        parameters += [Parameter.categoryId:"4d4b7105d754a06374d81259"] // Only Food category
        parameters += [Parameter.radius:"100"]
        
        print(parameters)
        
        let searchTask = session!.venues.search(parameters) {
            (result) -> Void in
            if let response = result.response
            {
//                print(response)
                
                var venues = response["venues"] as! [[String: AnyObject]]
                
                for venue in venues
                {
                    var name:String = venue["name"] as! String
                    
                    if  let location:[String:AnyObject] = venue["location"] as? [String:AnyObject],
                        let latitude:Double = location["lat"] as? Double,
                        let longitude:Double = location["lng"] as? Double,
                        let formattedAddress:[String] = location["formattedAddress"] as? [String]
                    {
                        var address = formattedAddress.joined(separator: " ")
                        
                        self.places.append([
                            "name": name,
                            "address": address,
                            "latitude": latitude,
                            "longitude": longitude
                            ])
                    }
                }
                
                self.places = self.places.sorted() {
                    item1, item2 in
                    let name1:String = item1["name"] as! String
                    let name2:String = item2["name"] as! String
                    return name1 < name2
                }
            }
            
            self.hasFinishedQuery = true
            self.updateDisplayedPlaces()
            self.tableView?.reloadData()
        }
        
        searchTask.start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
            
            var region = MKCoordinateRegion(center: newLocation.coordinate, latitudinalMeters: 200, longitudinalMeters: 200)
            
            if mapView != nil {
                
                var adjustRegion = mapView!.regionThatFits(region)
                
                mapView!.setRegion(adjustRegion, animated: true)
            }
            
            queryFoursquare(location: newLocation)
            
//            print(newLocation)
        }
    }
    
    func updateDisplayedPlaces() {
        if mapView == nil {
            return
        }
        
        mapView!.removeAnnotations(mapView!.annotations)
        
        for place:[String:Any] in places {
            if  let name:String = place["name"] as? String,
                let latitude:Double = place["latitude"] as? Double,
                let longitude:Double = place["longitude"] as? Double
            {
                var annotation:MKPointAnnotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2DMake(latitude as CLLocationDegrees, longitude as CLLocationDegrees)
                annotation.title = name
                
                mapView!.addAnnotation(annotation)
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseIdentifier = "annotation"
        
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        if(view == nil) {
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            view!.canShowCallout = true
        } else {
            view!.annotation = annotation
        }
        
        return view
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return places.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell:UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: "cellIdentifier")
    
        if cell == nil {
            cell = UITableViewCell(style:UITableViewCell.CellStyle.subtitle, reuseIdentifier:"cellIdentifier")
        }
    
        if indexPath.row < places.count {
        
            let row = places[indexPath.row]
    
            cell!.textLabel?.text = row["name"] as? String
            cell!.detailTextLabel?.text = row["address"] as? String
        }
    
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(mapView == nil) {
            return
        }
        
        let row = places[indexPath.row]
        
        if let name = row["name"] as? String {
            for annotation:MKAnnotation in mapView!.annotations {
                if let title = annotation.title {
                    if(name == title) {
                        mapView!.selectAnnotation(annotation, animated: true)
                        mapView!.setCenter(annotation.coordinate, animated: true)
                    }
                }
            }
        }
        
    }
}

extension CLLocation {
    func parameters() -> Parameters {
        let ll      = "\(self.coordinate.latitude),\(self.coordinate.longitude)"
        let llAcc   = "\(self.horizontalAccuracy)"
        let alt     = "\(self.altitude)"
        let altAcc  = "\(self.verticalAccuracy)"
        let parameters = [
            Parameter.ll:ll,
            Parameter.llAcc:llAcc,
            Parameter.alt:alt,
            Parameter.altAcc:altAcc
        ]
        
        return parameters
    }
}
