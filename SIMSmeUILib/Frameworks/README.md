# JitsiMeet Frameworks

As of 2020-10-16 the team at JitsiMeet still hasn't integrated our changes to the Delegate-API.

Thus, there is a repository at [Imdat's JitsiMeet Fork](https://github.com/imdatsolak/jitsi-meet).

In order not to have to built your own framework, we have provided these frameworks in this directory.

## Install JitsiMeet Framework

After you run a `pod install`, replace the two Frameworks in Pods/JitsiMeetSDK/Frameworks with the
framework files here.

That's all.

If you don't replace them, the only issue is that if the second-to-last user leaves a call, the last
user is NOT automatically ended. That's all.
