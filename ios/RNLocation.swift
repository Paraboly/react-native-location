//
//  RNLocation.swift
//  RNLocation
//
//  Created by Kuray ÖĞÜN on 8.03.2019.
//  Copyright © 2019 Facebook. All rights reserved.
//

import Foundation
import CoreLocation
import React

class RNLocation: CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var alwaysPermissionResolver: RCTPromiseResolveBlock?
    private var whenInUsePermissionResolver: RCTPromiseResolveBlock?
    private var hasListeners = false
    
    
    // MARK: - Initialization
    @objc
    func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }
    
    deinit {
        stopMonitoringSignificantLocationChanges()
        stopUpdatingLocation()
        stopUpdatingHeading()
        
        locationManager = nil
    }
    
    // MARK: - Listener tracking
    @objc
    func startObserving() {
        hasListeners = true
    }
    
    @objc
    func stopObserving() {
        hasListeners = false
    }
    
    @objc
    func supportedEvents() -> [String]? {
        return [
            "authorizationStatusDidChange",
            "headingUpdated",
            "locationUpdated",
            "onWarning"
        ]
    }
    
    @objc
    func requestAlwaysAuthorization(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        
        // Get the current status
        var status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        
        if status == .authorizedAlways {
            // We already have the correct status so resolve with true
            resolve(NSNumber(value: true))
        } else if status == .notDetermined || status == .authorizedWhenInUse {
            // If we have not asked, or we have "when in use" permission, ask for always permission
            locationManager.requestAlwaysAuthorization()
            // Save the resolver so we can return a result later on
            alwaysPermissionResolver = resolve
        } else {
            // We are not in a state to ask for permission so resolve with false
            resolve(NSNumber(value: false))
        }
    }
    
    @objc
    func requestWhenInUseAuthorization(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        // Get the current status
        var status: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            // We already have the correct status so resolve with true
            resolve(NSNumber(value: true))
        } else if status == .notDetermined {
            // If we have not asked, or we have "when in use" permission, ask for always permission
            locationManager.requestWhenInUseAuthorization()
            // Save the resolver so we can return a result later on
            whenInUsePermissionResolver = resolve
        } else {
            // We are not in a state to ask for permission so resolve with false
            resolve(NSNumber(value: false))
        }
    }

    
    @objc
    func getAuthorizationStatus(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) -> Void {
        var status = name(for: CLLocationManager.authorizationStatus())
        resolve(status)
    }
    
    
    @objc
    func configure(options: NSMutableDictionary){
        // Activity type
        var activityType = RCTConvert.nsString(options["activityType"])
        if (activityType == "other") {
            locationManager.activityType = .other
        } else if (activityType == "automotiveNavigation") {
            locationManager.activityType = .automotiveNavigation
        } else if (activityType == "fitness") {
            locationManager.activityType = .fitness
        } else if (activityType == "otherNavigation") {
            locationManager.activityType = .otherNavigation
        } else if (activityType == "airborne") {
            if #available(iOS 12.0, *) {
                locationManager.activityType = .airborne
            }
        }
        
        // Allows background location updates
        var allowsBackgroundLocationUpdates = RCTConvert.nsNumber(options["allowsBackgroundLocationUpdates"])
        if allowsBackgroundLocationUpdates != nil {
            locationManager.allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates.boolValue
        }
        
        // Desired accuracy
        var desiredAccuracy = RCTConvert.nsDictionary(options["desiredAccuracy"])
        if desiredAccuracy != nil {
            var desiredAccuracyIOS = RCTConvert.nsString(desiredAccuracy["ios"])
            if (desiredAccuracyIOS == "bestForNavigation") {
                locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            } else if (desiredAccuracyIOS == "best") {
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
            } else if (desiredAccuracyIOS == "nearestTenMeters") {
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            } else if (desiredAccuracyIOS == "hundredMeters") {
                locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            } else if (desiredAccuracyIOS == "threeKilometers") {
                locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            }
        }
        
        // Distance filter
        var distanceFilter = RCTConvert.nsNumber(options["distanceFilter"])
        if distanceFilter != nil {
            locationManager.distanceFilter = CLLocationDistance(distanceFilter.doubleValue)
        }
        
        // Heading filter
        var headingFilter = RCTConvert.nsNumber(options["headingFilter"])
        if headingFilter != nil {
            var headingFilterValue: Double = headingFilter.doubleValue
            locationManager.headingFilter = CLLocationDegrees(headingFilterValue == 0 ? kCLHeadingFilterNone : headingFilterValue)
        }
        
        // Heading orientation
        var headingOrientation = RCTConvert.nsString(options["headingOrientation"])
        if (headingOrientation == "portrait") {
            locationManager.headingOrientation = .portrait
        } else if (headingOrientation == "portraitUpsideDown") {
            locationManager.headingOrientation = .portraitUpsideDown
        } else if (headingOrientation == "landscapeLeft") {
            locationManager.headingOrientation = .landscapeLeft
        } else if (headingOrientation == "landscapeRight") {
            locationManager.headingOrientation = .landscapeRight
        }
        
        // Pauses location updates automatically
        var pausesLocationUpdatesAutomatically = RCTConvert.nsNumber(options["pausesLocationUpdatesAutomatically"])
        if pausesLocationUpdatesAutomatically != nil {
            locationManager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically.boolValue
        }
        
        // Shows background location indicator
        if #available(iOS 11.0, *) {
            var showsBackgroundLocationIndicator = RCTConvert.nsNumber(options["showsBackgroundLocationIndicator"])
            if showsBackgroundLocationIndicator != nil {
                locationManager.showsBackgroundLocationIndicator = showsBackgroundLocationIndicator.boolValue
            }
        }
    }
    
    // MARK: Monitoring
    @objc
    func startMonitoringSignificantLocationChanges(){
        self.locationManager.startMonitoringSignificantLocationChanges()
    }
    
    @objc
    func startUpdatingLocation(){
        self.locationManager.startUpdatingLocation()
    }
    
    @objc
    func startUpdatingHeading(){
        self.locationManager.startUpdatingHeading()
    }
    
    @objc
    func stopMonitoringSignificantLocationChanges(){
        self.locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    @objc
    func stopUpdatingLocation(){
        self.locationManager.stopUpdatingLocation()
    }
    
    @objc
    func stopUpdatingHeading(){
        self.locationManager.stopUpdatingHeading()
    }
    
    //MARK: CCLocationManagerDelegate
    @objc
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Handle the always permission resolver
        if alwaysPermissionResolver != nil {
            alwaysPermissionResolver(NSNumber(value: status == .authorizedAlways))
            alwaysPermissionResolver = nil
        }
        
        // Handle the when in use permission resolver
        if whenInUsePermissionResolver != nil {
            whenInUsePermissionResolver(NSNumber(value: status == .authorizedWhenInUse))
            whenInUsePermissionResolver = nil
        }
        
        // Handle the event listener
        if hasListeners {
            let statusName = name(for: status)
            sendEvent(withName: "authorizationStatusDidChange", body: statusName)
        }
    }
    
    @objc
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // TODO: Pass this to JS
        print("Location manager failed: \(error)")
    }
    
    @objc
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy < 0 {
            return
        }
        
        if !hasListeners {
            return
        }
        
        // Use the true heading if it is valid.
        let heading: CLLocationDirection = (newHeading.trueHeading > 0) ? newHeading.trueHeading : newHeading.magneticHeading
        
        let headingEvent = [
            "heading": NSNumber(value: heading)
        ]
        
        sendEvent(withName: "headingUpdated", body: headingEvent)
    }
    
    
    @objc
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !hasListeners {
            return
        }
        
        var results = [AnyHashable](repeating: 0, count: locations?.count ?? 0)
        (locations as NSArray?)?.enumerateObjects({ location, idx, stop in
            results.append([
                "latitude": NSNumber(value: location?.coordinate.latitude ?? 0),
                "longitude": NSNumber(value: location?.coordinate.longitude ?? 0),
                "altitude": NSNumber(value: location?.altitude ?? 0),
                "accuracy": NSNumber(value: location?.horizontalAccuracy ?? 0),
                "altitudeAccuracy": NSNumber(value: location?.verticalAccuracy ?? 0),
                "course": NSNumber(value: location?.course ?? 0),
                "speed": NSNumber(value: location?.speed ?? 0),
                "floor": NSNumber(value: location?.floor?.level ?? 0),
                "timestamp": NSNumber(value: (location?.timestamp.timeIntervalSince1970 ?? 0.0) * 1000) // in ms
                ])
        })
        
        
        sendEvent(withName: "locationUpdated", body: results)
    }
    
    //MARK: Utilities
    @objc
    func name(for authorizationStatus: CLAuthorizationStatus) -> String? {
        switch authorizationStatus {
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        case .denied:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        default:
            break
        }
    }
}



