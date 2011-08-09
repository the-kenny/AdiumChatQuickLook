# Adium Quicklook Generator #

This is a Quicklook generator for Mac OS X 10.5 or later which enables users to show the contents of a Adium Chatlog in a quickview-window.

This repository contains my modifications to the importer originally developed by jhagman, found in the [adium trac](http://trac.adium.im/ticket/7250)

All credits belong to jhagman

## Stripping Font Styles ##

If you don't want to see user-styles in the Quicklook-Window, run the following:

    defaults write im.adium.quicklookImporter stripStyles -bool true

You can re-enable styles with the following command:

    defaults write im.adium.quicklookImporter stripStyles -bool false
