//
//  Detector.m
//  OpenCVTutorial
//
//  Created by 小林 孝稔 on 2015/05/15.
//  Copyright (c) 2015年 小林 孝稔. All rights reserved.
//

#import "OpenCVTutorial-Bridging-Header.h"
#import <opencv2/opencv.hpp>
#import <opencv2/highgui/ios.h>
#import <opencv2/video/background_segm.hpp>

using namespace cv;

@interface Detector()
{
    cv::CascadeClassifier cascade;
    Mat frame;
    Mat curr;
    Mat prev;
    Ptr<BackgroundSubtractor> pMOG2;
}
@end

@implementation Detector: NSObject

- (id)init {
    self = [super init];
    
    pMOG2 = new BackgroundSubtractorMOG2(1, 0, false);
    
    return self;
}

- (UIImage *)recognizeFace:(UIImage *)image {
    // UIImage -> cv::Mat変換
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat mat(rows, cols, CV_8UC4);
    

    CGContextRef contextRef = CGBitmapContextCreate(mat.data,
                                                    cols,
                                                    rows,
                                                    8,
                                                    mat.step[0],
                                                    colorSpace,
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    // 顔検出
    std::vector<cv::Rect> faces;
    cascade.detectMultiScale(mat, faces,
                             1.1, 2,
                             CV_HAAR_SCALE_IMAGE,
                             cv::Size(30, 30));
    
    // 顔の位置に丸を描く
    std::vector<cv::Rect>::const_iterator r = faces.begin();
    for(; r != faces.end(); ++r) {
        cv::Point center;
        int radius;
        center.x = cv::saturate_cast<int>((r->x + r->width*0.5));
        center.y = cv::saturate_cast<int>((r->y + r->height*0.5));
        radius = cv::saturate_cast<int>((r->width + r->height));
        cv::circle(mat, center, radius, cv::Scalar(80,80,255), 3, 8, 0 );
    }
    
    
    // cv::Mat -> UIImage変換
    UIImage *resultImage = MatToUIImage(mat);
    
    return resultImage;
}

- (UIImage *)recognizeGesture:(UIImage *)image {
    // UIImage -> cv::Mat変換
    frame = [self cvMatFromUIImage:image];
    
    pMOG2->operator()(frame, curr, 0.9);
    
    //輪郭の座標リスト
    std::vector< std::vector< cv::Point > > contours;
    
    //輪郭取得
    Mat contourImg = curr.clone();
    ////cv::findContours(binImage, contours, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_NONE);
    cv::findContours(contourImg, contours, CV_RETR_LIST, CV_CHAIN_APPROX_NONE);
    
    // 検出された輪郭線を緑で描画
    for (auto contour = contours.begin(); contour != contours.end(); contour++){
//        cv::polylines(curr, *contour, true, cv::Scalar(0, 255, 0), 2);
    }
    
    //輪郭の数
    int roiCnt = 0;
    
    //輪郭のカウント
    int i = 0;
    
    /*
    for (auto contour = contours.begin(); contour != contours.end(); contour++){
        
        std::vector< cv::Point > approx;
        
        //輪郭を直線近似する
        cv::approxPolyDP(cv::Mat(*contour), approx, 0.01 * cv::arcLength(*contour, true), true);
        
        // 近似の面積が一定以上なら取得
        double area = cv::contourArea(approx);
        
        if (area > 1000.0){
            //青で囲む場合
            cv::polylines(imgIn, approx, true, cv::Scalar(255, 0, 0), 2);
            std::stringstream sst;
            sst << "area : " << area;
            cv::putText(imgIn, sst.str(), approx[0], CV_FONT_HERSHEY_PLAIN, 1.0, cv::Scalar(0, 128, 0));
            
            //輪郭に隣接する矩形の取得
            cv::Rect brect = cv::boundingRect(cv::Mat(approx).reshape(2));
            roi[roiCnt] = cv::Mat(imgIn, brect);
            
            //入力画像に表示する場合
            //cv::drawContours(imgIn, contours, i, CV_RGB(0, 0, 255), 4);
            
            //表示
            cv::imshow("label" + std::to_string(roiCnt+1), roi[roiCnt]);
            
            roiCnt++;
            
            //念のため輪郭をカウント
            if (roiCnt == 99)
            {
                break;
            }
        }
        
        i++;
    }
     */
    
    // cv::Mat -> UIImage変換
    UIImage *resultImage = MatToUIImage(curr);
    
    return resultImage;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
//    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

- (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                              //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end