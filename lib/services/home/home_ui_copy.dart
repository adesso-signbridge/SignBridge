/// Localized UI strings for the home / talk experience.
class HomeUiCopy {
  const HomeUiCopy({
    required this.emptyStateMessage,
    required this.tapToListen,
    required this.tapToSign,
    required this.tapToStop,
    required this.listeningLabel,
    required this.signingPrefix,
    required this.signingListeningWord,
    required this.heardLabel,
    required this.clearHistoryLabel,
    required this.noSpeechDetectedLabel,
    required this.micPermissionRequiredLabel,
    required this.listenStartFailedLabel,
    required this.talkTabLabel,
    required this.phrasesTabLabel,
    required this.settingsTitle,
    required this.emergencySection,
    required this.callEmergency,
    required this.sos,
    required this.aboutSection,
    required this.appLabel,
    required this.versionLabel,
    required this.footerCopyright,
  });

  final String emptyStateMessage;
  final String tapToListen;
  final String tapToSign;
  final String tapToStop;
  final String listeningLabel;
  final String signingPrefix;
  final String signingListeningWord;
  final String heardLabel;
  final String clearHistoryLabel;
  final String noSpeechDetectedLabel;
  final String micPermissionRequiredLabel;
  final String listenStartFailedLabel;
  final String talkTabLabel;
  final String phrasesTabLabel;
  final String settingsTitle;
  final String emergencySection;
  final String callEmergency;
  final String sos;
  final String aboutSection;
  final String appLabel;
  final String versionLabel;
  final String footerCopyright;
}

const _homeUiCopyByLanguage = <String, HomeUiCopy>{
  'ENG': HomeUiCopy(
    emptyStateMessage: 'No conversation yet.\nUse the buttons below to start.',
    tapToListen: 'Tap to listen',
    tapToSign: 'Tap to sign',
    tapToStop: 'Tap to stop',
    listeningLabel: 'Listening...',
    signingPrefix: 'Signing:',
    signingListeningWord: '...',
    heardLabel: 'Heard',
    clearHistoryLabel: 'Clear history',
    noSpeechDetectedLabel: 'No speech detected.',
    micPermissionRequiredLabel: 'Microphone permission is required to listen.',
    listenStartFailedLabel: 'Could not start listening. Please try again.',
    talkTabLabel: 'Talk',
    phrasesTabLabel: 'Phrases',
    settingsTitle: 'Settings',
    emergencySection: 'EMERGENCY',
    callEmergency: 'Call Emergency',
    sos: 'SOS',
    aboutSection: 'ABOUT',
    appLabel: 'App',
    versionLabel: 'Version',
    footerCopyright: '© 2026 adesso India',
  ),
  'ML': HomeUiCopy(
    emptyStateMessage:
        'ഇതുവരെ സംഭാഷണമില്ല.\nആരംഭിക്കാൻ താഴെയുള്ള ബട്ടണുകൾ ഉപയോഗിക്കുക.',
    tapToListen: 'കേൾക്കാൻ ടാപ്പ് ചെയ്യുക',
    tapToSign: 'സൈൻ ചെയ്യാൻ ടാപ്പ് ചെയ്യുക',
    tapToStop: 'നിർത്താൻ ടാപ്പ് ചെയ്യുക',
    listeningLabel: 'കേൾക്കുന്നു...',
    signingPrefix: 'സൈൻ ചെയ്യുന്നു:',
    signingListeningWord: '...',
    heardLabel: 'കേട്ടു',
    clearHistoryLabel: 'ചരിത്രം മായ്ക്കുക',
    noSpeechDetectedLabel: 'സംസാരം കണ്ടെത്തിയില്ല.',
    micPermissionRequiredLabel: 'കേൾക്കാൻ മൈക്രോഫോൺ അനുമതി ആവശ്യമാണ്.',
    listenStartFailedLabel:
        'കേൾക്കൽ ആരംഭിക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക.',
    talkTabLabel: 'സംസാരം',
    phrasesTabLabel: 'വാചകങ്ങൾ',
    settingsTitle: 'ക്രമീകരണങ്ങൾ',
    emergencySection: 'അടിയന്തരാവസ്ഥ',
    callEmergency: 'അടിയന്തര കോൾ',
    sos: 'SOS',
    aboutSection: 'കുറിച്ച്',
    appLabel: 'ആപ്പ്',
    versionLabel: 'പതിപ്പ്',
    footerCopyright: '© 2026 adesso India',
  ),
  'HI': HomeUiCopy(
    emptyStateMessage:
        'अभी तक कोई बातचीत नहीं।\nशुरू करने के लिए नीचे दिए बटन का उपयोग करें।',
    tapToListen: 'सुनने के लिए टैप करें',
    tapToSign: 'साइन करने के लिए टैप करें',
    tapToStop: 'रोकने के लिए टैप करें',
    listeningLabel: 'सुन रहा है...',
    signingPrefix: 'साइन कर रहा है:',
    signingListeningWord: '...',
    heardLabel: 'सुना',
    clearHistoryLabel: 'इतिहास साफ़ करें',
    noSpeechDetectedLabel: 'कोई भाषण नहीं मिला।',
    micPermissionRequiredLabel: 'सुनने के लिए माइक्रोफ़ोन अनुमति आवश्यक है।',
    listenStartFailedLabel: 'सुनना शुरू नहीं हो सका। कृपया पुनः प्रयास करें।',
    talkTabLabel: 'बातचीत',
    phrasesTabLabel: 'वाक्यांश',
    settingsTitle: 'सेटिंग्स',
    emergencySection: 'आपातकाल',
    callEmergency: 'आपातकालीन कॉल',
    sos: 'SOS',
    aboutSection: 'के बारे में',
    appLabel: 'ऐप',
    versionLabel: 'संस्करण',
    footerCopyright: '© 2026 adesso India',
  ),
  'TA': HomeUiCopy(
    emptyStateMessage:
        'இன்னும் உரையாடல் இல்லை.\nதொடங்க கீழுள்ள பொத்தான்களைப் பயன்படுத்தவும்.',
    tapToListen: 'கேட்க தட்டவும்',
    tapToSign: 'சைகை செய்ய தட்டவும்',
    tapToStop: 'நிறுத்த தட்டவும்',
    listeningLabel: 'கேட்கிறது...',
    signingPrefix: 'சைகை செய்கிறது:',
    signingListeningWord: '...',
    heardLabel: 'கேட்டது',
    clearHistoryLabel: 'வரலாற்றை அழிக்க',
    noSpeechDetectedLabel: 'பேச்சு கண்டறியப்படவில்லை.',
    micPermissionRequiredLabel: 'கேட்க மைக்ரோஃபோன் அனுமதி தேவை.',
    listenStartFailedLabel:
        'கேட்பதைத் தொடங்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
    talkTabLabel: 'பேச்சு',
    phrasesTabLabel: 'சொற்றொடர்கள்',
    settingsTitle: 'அமைப்புகள்',
    emergencySection: 'அவசரம்',
    callEmergency: 'அவசர அழைப்பு',
    sos: 'SOS',
    aboutSection: 'பற்றி',
    appLabel: 'பயன்பாடு',
    versionLabel: 'பதிப்பு',
    footerCopyright: '© 2026 adesso India',
  ),
};

HomeUiCopy homeUiCopyFor(String languageCode) {
  return _homeUiCopyByLanguage[languageCode] ?? _homeUiCopyByLanguage['ENG']!;
}
