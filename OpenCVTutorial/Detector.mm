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
    cv::Point prevCenter;
    float delta;
    GestureType gestureType;
}
@end

@implementation Detector: NSObject

- (id)init {
    self = [super init];
    
    pMOG2 = new BackgroundSubtractorMOG2(1, 0, false);
    gestureType = GestureType::RIGHT;
    
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
    
    // 背景差分法
    pMOG2->operator()(frame, curr, 0.8);
    
    // ノイズ除去
    Mat gaussian;
    GaussianBlur(curr, gaussian, Size2f(9, 9), 5);

    // 2値化
    Mat bin;
    threshold(gaussian, bin, 200, 255, cv::THRESH_BINARY);

    // 重心計算
    IplImage binImg = bin;
    CvMoments moment;
    cvMoments(&binImg, &moment);
    cv::Point currCenter;
    double m00 = cvGetSpatialMoment(&moment, 0,0);
    currCenter.x = cvGetSpatialMoment(&moment, 1,0) / m00;
    currCenter.y = cvGetSpatialMoment(&moment, 0,1) / m00;
    cv::circle(bin, currCenter, 50, cv::Scalar(80,80,255), 3, 8, 0);
    
    if (abs(currCenter.x - prevCenter.x) > 200 && prevCenter.x != 0 && currCenter.x != 0) {
        double dx = currCenter.x - prevCenter.x;
        double dy = currCenter.y - prevCenter.y;
        double angle = atan2(dy, dx) * 180 / M_PI;
        prevCenter = cv::Point(0, 0);
        NSLog(@"x=%d, y=%d", currCenter.x, currCenter.y);
        NSLog(@"angle=%f", angle);
        
        if (angle > -90.0 && angle < 90.0) {
            gestureType = GestureType::LEFT;
        } else if ((angle > 90.0 && angle < 180.0) || (angle > -180.0 && angle < -90.0)) {
            gestureType = GestureType::RIGHT;
        }
    }
    
    // 初期座標更新
    if (prevCenter.x == 0 && currCenter.x != 0) {
        prevCenter = currCenter;
        delta = 0;
    }
    
    // 一定時間経過後リセット
    if (++delta > 20.0) {
        prevCenter = cv::Point(0, 0);
        delta = 0;
    }

    // cv::Mat -> UIImage変換
    UIImage *resultImage = MatToUIImage(bin);
    
    return resultImage;
}

- (GestureType)getGestureType
{
    return gestureType;
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