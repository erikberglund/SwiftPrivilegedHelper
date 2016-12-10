# SwiftPrivilegedHelper

This is an example application to demonstrate how to use a privileged helper tool with authentication in Swift 3.0.

Please undestand the code and improve and customize it to suit your needs and your application. The example code contain minimal error handling and can be improved in many ways.

# Index

* [Requirements](https://github.com/erikberglund/SwiftPrivilegedHelper#requirements)
* [Setup](https://github.com/erikberglund/SwiftPrivilegedHelper#setup)
* [Application](https://github.com/erikberglund/SwiftPrivilegedHelper#application)
* [References](https://github.com/erikberglund/SwiftPrivilegedHelper#references)

# Requirements

* **Tool and language versions**  
 This project was created and only tested using Xcode Version 8.1 (8B62) and Swift 3.0.

* **Developer Certificate**  
 To use a privileged helper tool the application and helper has to be signed by a valid deverloper certificate.  
 I'm using manual signing with a Developer ID certificate in the application, so the guide will assume that setup.

* **SMJobBlessUtil**  
 The python tool for verifying signing of applications using SMJobBless included in the [SMJobBless](https://developer.apple.com/library/content/samplecode/SMJobBless/Introduction/Intro.html#//apple_ref/doc/uid/DTS40010071-Intro-DontLinkElementID_2) example project is extremely useful for troubleshooting signing issues.  
 
 Dowload it here: [SMJobBlessUtil.py](https://developer.apple.com/library/content/samplecode/SMJobBless/Listings/SMJobBlessUtil_py.html)
 
 Use it like this: `./SMJobBlessUtil.py check /path/to/MyApplication.app`

# Setup

To test the project, you need to update it to use your own signing certificate.

### Select signing team
1. Select the project in the navigator.
2. For **both** the application and helper targets:
3. Change the signing Team to your Team.  
 ![ChangeSigningTeam](https://github.com/erikberglund/SwiftPrivilegedHelper/blob/master/Screenshots/ChangeSigningTeam.png)
 
### Change signing certificate OU
1. Find the OU of the Developer ID certificate you selected in the application:
 
 ```bash
 $ grep DevelopmentTeam /path/to/SwiftPrivilegedHelper/MyApplication.xcodeproj/project.pbxproj
 DevelopmentTeam = Y7QFC8672N;
 ```
2. For **both** the application and helper Info.plist:
3. Replace the OU with your own in **Tools owned after installation** and **Clients allowed to add and remove tool** respectively.  
 ![ChangeCertificateOU](https://github.com/erikberglund/SwiftPrivilegedHelper/blob/master/Screenshots/ChangeCertificateOU.png)

Build and test the application.

### Signing Troubleshooting

Use [SMJobBlessUtil.py](https://developer.apple.com/library/content/samplecode/SMJobBless/Listings/SMJobBlessUtil_py.html) and correct all issues reported until it doesn't show any output.

# Application

The application installs the helper tool using SMJobBless.

After the tool is installed, you can enter a directory path in the text field at the top and select to either run the `/bin/ls` command with that path as the argument as root using the helper tool either with or without requiring authorization.

The output is shown in the textview below.

This application caches the authorization reference which means that if you have authorized once, you won't have to do that again until you press the "Destroy the cached authorization reference".

This behaviour can easily be changed to either require authrization every time the button is clicked, or after x seconds or never.

# References

The following are links to documentation on the authorization system on macOS.

* [Authorization Services Programming Guide](https://developer.apple.com/library/content/documentation/Security/Conceptual/authorization_concepts/01introduction/introduction.html#//apple_ref/doc/uid/TP30000995-CH204-TP1)
* [Technical Note TN2095 - Authorization for Everyone](https://developer.apple.com/library/content/technotes/tn2095/_index.html)