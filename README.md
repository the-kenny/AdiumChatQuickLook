# Adium Quicklook Generator #

This is a Quicklook generator for Mac OS X 10.5 or later which enables users to show the contents of a Adium Chatlog in a quickview-window. (Space key in Finder.app)

This repository is an indirect fork from [Doug Harris](https://github.com/dougharris/AdiumChatQuickLook) with modifications by jhagman found in the [Adium trac](http://trac.adium.im/ticket/7250)

## Installation ##

    xcodebuild -configuration Release
    cp -r build/Release/AdiumChatQuickLook.qlgenerator ~/Library/QuickLook/
    killall quicklookd32

## Configuration ##

### Stripping Font Styles ###

If you don't want to see user-styles in the Quicklook-Window, run the following:

    defaults write im.adium.quicklookImporter stripStyles -bool true

You can re-enable styles with the following command:

    defaults write im.adium.quicklookImporter stripStyles -bool false

### Changing Message Limit ###

The quicklook generator shows up to 50 messages per-default. You can change the limit with the following command:

    defaults write im.adium.quicklookImporter messageLimit -integer NUMBER

where NUMBER is the limit you want to set.
