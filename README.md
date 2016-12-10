# SwiftPrivilegedHelper

This is just an example application to demonstrate how to use a privileged helper tool with authentication in Swift 3.0.

Please undestand the code and improve and customize it to suit your need and application, this is just a simple example with minimal error handling and error checks.

# Requirements

* **Tool and language versions**  
 This project was created and only tested using Xcode Version 8.1 (8B62) and written in Swift 3.0.

* **Developer Certificate**  
 To use a privileged helper tool, the application and helper has to be signed by a valid deverloper certificate.  
 I'm using manual signing with a `Developer ID` certificate in the application, so the guide will assume that setup.

* **SMJobBlessUtil**  
 The python tool for verifying signing for applications using SMJobBless included in the [SMJobBless](https://developer.apple.com/library/content/samplecode/SMJobBless/Introduction/Intro.html#//apple_ref/doc/uid/DTS40010071-Intro-DontLinkElementID_2) example project is extremely useful for troubleshooting signing issues.  
 Dowload it here: [SMJobBlessUtil.py](https://developer.apple.com/library/content/samplecode/SMJobBless/Listings/SMJobBlessUtil_py.html)

# Setup

To use the project, you need to use your own signing certificate.

### Select signing team
1. Select the project in the navigator
2. For both the application and helper targets:
3. Change the signing Team to your Team:  
 ![ChangeSigningTeam](https://github.com/erikberglund/SwiftPrivilegedHelper/blob/master/Screenshots/ChangeSigningTeam.png)
 
### Change signing certificate OU
1. Find the OU of the Developer ID certificate you selected in the application. You look for the DevelopmentTeam in the pbxproj file inside the xcode project file.  
 ```bash
 $ grep DevelopmentTeam SwiftPrivilegedHelper/MyApplication.xcodeproj/project.pbxproj
 DevelopmentTeam = Y7QFC8672N;
 DevelopmentTeam = Y7QFC8672N;
 ```
2. For both the application and helper Info.plist:
3. Change the OU in the _Tools owned after installation_ and _Clients allowed to add and remove tool_ respectively to your certificate OU:  
 ![ChangeCertificateOU](https://github.com/erikberglund/SwiftPrivilegedHelper/blob/master/Screenshots/ChangeCertificateOU.png)