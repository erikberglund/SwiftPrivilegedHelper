#  CodeSignUpdate

`CodeSignUpdate.swift` is based on and replaces the `CodeSignUpdate.sh` shell script created by Erik Berglund.  I [Chip Jarred](https://github.com/chipjarred), found [Eric's project](https://github.com/erikberglund/SwiftPrivilegedHelper) extremely useful in helping solve some problem code signing issues with my helper tool, and decided to contribute some further improvements that could have made my trouble-shooting even shorter.

`CodeSignUpdate.swift` is intended to be used as a Swift script in a *Run Script* build phase, though you could, of course, actually compile it.   It's job is the same as Erik's shell script: To fill in the correct code signing certificate information in the plists of both a main application and the helper tool it uses for priviledge escalation.  His script was, in my opinion, a nice improvement on the way you'd have to do that task before, which was do manually invoke Apple's `SMJobBlessUtility.py` script, which may not have been so bad in the days when Xcode did in-project builds, but with builds done deep inside your Library folder, specyfing the app path plus the paths for both of your plists was kind of pain, and even that was an improvement over doing every single step yourself.  I hope you'll agree that this Swift version is another step toward making building an app with a priviledged helper tool just a little easier.  

So, apart from the implementation language, what's different?

The shell script used `stdout` as a means of string building, and so couldn't use it to give useful error information in the build log.  If things didn't work, you'd just get a build error saying that the script terminated with exit code 1 with no other information.  It did generate a few error messages, but most of them were in a context in which  `stdout` was being redirected to build the string, and since those errors would be followed by a call to `exit`, they would be lost. 

Because `CodeSignUpdate.swift` is written in Swift, it is able to build strings without redirecting I/O, and so is able to generate useful error messages that you can actually see.   It also generates more detailed and, I hope, useful messages for things the original didn't check to help you track down and fix whatever is causing it to fail. 

It also eliminates the hard-coding of bundle ids in the script itself.  You provide them by `export`ing them as shell variables before calling the script in your *Run Script* phase, which should run after *Dependencies*, but before *Compile Sources*.  For example

    export MAIN_BUNDLE_ID="com.github.erikberglund.SwiftPrivilegedHelperApplication"
    export HELPER_BUNDLE_ID="com.github.erikberglund.SwiftPrivilegedHelper"
    swift "${SRCROOT}"/Scripts/CodeSignUpdate.swift

If you forget to include the `export` commands, the script will remind you. 

This Swift version accomplishes the job of editing the plists very differently than the shell script version did.  This particular difference isn't necessarily better.  It's just a matter of each version using the most convenient tools available to it to get the job done.  The shell script called the `/usr/libexec/PlistBuddy` tool and `sed` to edit the plists.   The Swift version reads the plists into dictionaries, which it modifies itself, then writes back out to the plists. 

Since it has to read and process the info.plists anyway, it checks that the bundle IDs in them are consistent with each other.  If they weren't that could cause problems in the actual code signing phase.  It checks that your helper tool's bundle id and name match the `HELPER_BUNDLE_ID` environment variable you set, and for your main app, it checks that your the `MAIN_BUNDLE_ID` matches the `PRODUCT_BUNDLE_ID` environment variable that Xcode generates from your build settings.
