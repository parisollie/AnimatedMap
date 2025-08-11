//
//  ContentView.swift
//  AnimatedMap
//
//  Created by Paul F on 11/08/25.
//

import SwiftUI
import MapKit


// MARK: - Marker Model

struct Marker: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Main Content View

struct ContentView: View {
    
    // Initial region (centered on San Francisco).
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    // Map type (standard or satellite).
    @State private var selectedMapType: MKMapType = .standard
    
    // List of markers to display on the map.
    @State private var markers: [Marker] = []
    
    // Whether we're currently showing San Francisco or Los Angeles.
    @State private var isShowingSF = true
    
    // Whether the map is flipped in 3D (eye-catching animation).
    @State private var isFlipped = false
    
    var body: some View {
        ZStack {
            // A custom UIViewRepresentable map that accepts:
            // - region binding
            // - map type
            // - markers
            // - a boolean isFlipped (to show a 3D rotation)
            AnimatedMapView(
                region: $region,
                mapType: selectedMapType,
                markers: markers,
                isFlipped: isFlipped
            )
            .ignoresSafeArea() // Full-screen map
            
            // Overlay UI
            VStack {
                // Top controls: map type picker & flip button
                HStack {
                    Picker("Map Type", selection: $selectedMapType) {
                        Text("Standard").tag(MKMapType.standard)
                        Text("Satellite").tag(MKMapType.satellite)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        // Toggle the 3D flip animation
                        withAnimation(.easeInOut(duration: 1.0)) {
                            isFlipped.toggle()
                        }
                    } label: {
                        Image(systemName: "arrow.2.circlepath.circle")
                            .font(.title2)
                            .padding(8)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 20) {
                    // Button to animate region between SF and LA
                    Button {
                        withAnimation(.easeInOut(duration: 2.0)) {
                            if isShowingSF {
                                // Los Angeles
                                region.center = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
                            } else {
                                // San Francisco
                                region.center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                            }
                            isShowingSF.toggle()
                        }
                    } label: {
                        Label(
                            isShowingSF ? "Los Angeles" : "San Francisco",
                            systemImage: "airplane"
                        )
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Add a random marker
                    Button {
                        let randomCoord = randomCoordinate(in: region)
                        markers.append(Marker(coordinate: randomCoord))
                    } label: {
                        Label("Add Marker", systemImage: "mappin.and.ellipse")
                            .padding(8)
                            .background(Color.green.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Clear all markers
                    Button {
                        markers.removeAll()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .padding(8)
                            .background(Color.red.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    /// Generate a random coordinate within the current visible region of the map.
    private func randomCoordinate(in region: MKCoordinateRegion) -> CLLocationCoordinate2D {
        let latRange = region.span.latitudeDelta / 2.0
        let lonRange = region.span.longitudeDelta / 2.0
        
        let minLat = region.center.latitude - latRange
        let maxLat = region.center.latitude + latRange
        let minLon = region.center.longitude - lonRange
        let maxLon = region.center.longitude + lonRange
        
        let randomLat = Double.random(in: minLat...maxLat)
        let randomLon = Double.random(in: minLon...maxLon)
        
        return CLLocationCoordinate2D(latitude: randomLat, longitude: randomLon)
    }
}

// MARK: - UIViewRepresentable for MKMapView with 3D Flip

/// A wrapper around MKMapView that supports:
/// - a binding region
/// - a chosen map type
/// - an array of markers
/// - a 3D flip effect via SwiftUI's rotation3DEffect
struct AnimatedMapView: UIViewRepresentable {
    
    @Binding var region: MKCoordinateRegion
    let mapType: MKMapType
    let markers: [Marker]
    let isFlipped: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Set the initial region (no animation).
        mapView.setRegion(region, animated: false)
        
        // Set map type
        mapView.mapType = mapType
        
        // Return the mapView to SwiftUI
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update the region (animated) if changed
        uiView.setRegion(region, animated: true)
        
        // Update the map type
        if uiView.mapType != mapType {
            uiView.mapType = mapType
        }
        
        // Clear existing annotations
        let existingAnnotations = uiView.annotations
        uiView.removeAnnotations(existingAnnotations)
        
        // Create & add new annotations
        let newAnnotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            return annotation
        }
        uiView.addAnnotations(newAnnotations)
        
        // Apply a 3D flip using SwiftUI's rotation3DEffect by adjusting the layer transform.
        // We can't directly apply SwiftUI modifiers in UIViewRepresentable,
        // so we handle it via the map view's CALayer.
        let angle = isFlipped ? CGFloat.pi : 0
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 500 // perspective
        transform = CATransform3DRotate(transform, angle, 0, 1, 0)
        
        UIView.animate(withDuration: 1.0) {
            uiView.layer.transform = transform
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        // Implement MKMapViewDelegate methods if needed
    }
}


#Preview {
    ContentView()
}
