//
//  ContentView.swift
//  SUIMLCamera
//
//  Created by yury antony on 10/10/21.
//

import SwiftUI
import AVFoundation
//import CoreML

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    
    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea(.all, edges: .all)
            VStack {
                
                if camera.isTaken {
                    HStack {
                        Spacer()
                        Button(action: {camera.reTakePic()}, label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .foregroundColor(Color("MainSUIML"))
                                .padding()
                                .background(Color("SecondarySUIML"))
                                .clipShape(Circle())
                        })
                            .padding(.trailing, 10)
                    }
                    Spacer()
                }
                Spacer()
                HStack {
                    if camera.isTaken {
                        Button(action: {if !camera.isSaved{camera.savePic()}}, label: {
                            Text(camera.isSaved ? camera.resultado:"Avaliar")
                                .foregroundColor(Color("MainSUIML"))
                                .fontWeight(.semibold)
                                .padding(.vertical,10)
                                .padding(.horizontal,20)
                                .background(Color("SecondarySUIML"))
                                .clipShape(Capsule())
                        })
                            .padding(.leading)
                        Spacer()
                    } else {
                        Button(action: {camera.takePic()}, label: {
                            ZStack{
                                Circle()
                                    .fill(Color("SecondarySUIML"))
                                    .frame(width: 65, height: 65)
                                Circle()
                                    .stroke(Color("SecondarySUIML"), lineWidth: 2)
                                    .frame(width: 70, height: 70)
                                
                            }
                        })
                    }
                }
                .frame(height: 75)
            }
        }
        .onAppear(perform: {
            camera.checkAuth()
        })
    }
}

class CameraModel:  NSObject,ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isSaved = false
    @Published var picData = Data(count: 0)
    var resultado = "Resultado"
    
//    let catdogModel:MeuModeloML = {
//        let model = try? MeuModeloML(configuration: MLModelConfiguration())
//        return model!
//    }()
    
    func checkAuth() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (status) in
                if status {
                    self.setup()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
        }
    }
    
    func setup() {
        do  {
            self.session.beginConfiguration()
            let device = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
            let input = try AVCaptureDeviceInput(device: device!)
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            self.session.commitConfiguration()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    func takePic() {
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
            }
        }
    }
    
    func reTakePic() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                withAnimation{self.isTaken.toggle()}
                self.isSaved = false
            }
        }
    }
    
    func savePic() {
        let image = UIImage(data: self.picData)!
//        let inputML = MeuModeloML(image: ImageProcessor.pixelBuffer(forImage: image)!)
        
//        let mlResult: MeuModeloML = {
//            let result = try? self.catdogModel.prediction(image: inputML.image)
//            return result!
//        }()
        
        //self.resultado = mlResult
        self.isSaved = true
        print("Saved")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            return
        }
        print("Pic taken ...")
        
        guard let imageData = photo.fileDataRepresentation() else {return}
        self.picData = imageData
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera : CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        camera.session.startRunning()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}

struct ImageProcessor {
    static func pixelBuffer (forImage im:UIImage) -> CVPixelBuffer? {
        let image = im.cgImage!
        
        let frameSize = CGSize(width: image.width, height: image.height)
        
        var pixelBuffer:CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
        
        if status != kCVReturnSuccess {
            return nil
            
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
        
    }
    
}
