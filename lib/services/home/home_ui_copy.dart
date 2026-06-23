/// Localized UI strings for the home / talk experience.
class HomeUiCopy {
  const HomeUiCopy({
    required this.emptyStateMessage,
    required this.tapToListen,
    required this.tapToSign,
    required this.tapToTranslate,
    required this.tapToStop,
    required this.sendCaptionLabel,
    required this.flipCameraLabel,
    required this.clearCaptionLabel,
    required this.recordingSignsLabel,
    required this.analyzingSignsLabel,
    required this.spokenLabel,
    required this.signsCapturedLabel,
    required this.replayLabel,
    required this.cameraPermissionRequiredLabel,
    required this.signCaptureFailedLabel,
    required this.signCaptureRateLimitedLabel,
    required this.signCaptureModelUnavailableLabel,
    required this.signCaptureServiceUnavailableLabel,
    required this.signCaptureNotConfiguredLabel,
    required this.signCaptureUnauthorizedLabel,
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
    required this.callEmergencyConfirmTitle,
    required this.callEmergencyConfirmBody,
    required this.sosConfirmTitle,
    required this.sosConfirmBody,
    required this.emergencyCancelLabel,
    required this.emergencyConfirmLabel,
    required this.emergencyCallFailedLabel,
    required this.sosCountdownTitle,
    required this.sosCountdownBody,
    required this.sosCountdownCancelLabel,
    required this.emergencyPhonePermissionRequiredLabel,
    required this.signRecordingTooShortLabel,
    required this.signRecordingEmptyLabel,
    required this.signNoSignsDetectedLabel,
    required this.aboutSection,
    required this.appLabel,
    required this.versionLabel,
    required this.footerCopyright,
    required this.languageChangeConfirmTitle,
    required this.languageChangeConfirmLabel,
    required this.languageChangeConfirmListeningBody,
    required this.languageChangeConfirmRecordingBody,
    required this.languageChangeBlockedAnalyzingLabel,
    required this.languageChangeBlockedEmergencyLabel,
    required this.languageChangedSnackbar,
  });

  final String emptyStateMessage;
  final String tapToListen;
  final String tapToSign;
  final String tapToTranslate;
  final String tapToStop;
  final String sendCaptionLabel;
  final String flipCameraLabel;
  final String clearCaptionLabel;
  final String recordingSignsLabel;
  final String analyzingSignsLabel;
  final String spokenLabel;
  final String signsCapturedLabel;
  final String replayLabel;
  final String cameraPermissionRequiredLabel;
  final String signCaptureFailedLabel;
  final String signCaptureRateLimitedLabel;
  final String signCaptureModelUnavailableLabel;
  final String signCaptureServiceUnavailableLabel;
  final String signCaptureNotConfiguredLabel;
  final String signCaptureUnauthorizedLabel;
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
  final String callEmergencyConfirmTitle;
  final String callEmergencyConfirmBody;
  final String sosConfirmTitle;
  final String sosConfirmBody;
  final String emergencyCancelLabel;
  final String emergencyConfirmLabel;
  final String emergencyCallFailedLabel;
  final String sosCountdownTitle;
  final String sosCountdownBody;
  final String sosCountdownCancelLabel;
  final String emergencyPhonePermissionRequiredLabel;
  final String signRecordingTooShortLabel;
  final String signRecordingEmptyLabel;
  final String signNoSignsDetectedLabel;
  final String aboutSection;
  final String appLabel;
  final String versionLabel;
  final String footerCopyright;
  final String languageChangeConfirmTitle;
  final String languageChangeConfirmLabel;
  final String languageChangeConfirmListeningBody;
  final String languageChangeConfirmRecordingBody;
  final String languageChangeBlockedAnalyzingLabel;
  final String languageChangeBlockedEmergencyLabel;

  /// Snackbar after a successful change. Use [languageChangedSnackbarFor].
  final String languageChangedSnackbar;

  String languageChangedSnackbarFor(String languageLabel) {
    return languageChangedSnackbar.replaceAll('{language}', languageLabel);
  }
}

const _homeUiCopyByLanguage = <String, HomeUiCopy>{
  'ENG': HomeUiCopy(
    emptyStateMessage: 'No conversation yet.\nUse the buttons below to start.',
    tapToListen: 'Tap to listen',
    tapToSign: 'Tap to sign',
    tapToTranslate: 'Tap to translate',
    tapToStop: 'Tap to stop',
    sendCaptionLabel: 'Send',
    flipCameraLabel: 'Flip camera',
    clearCaptionLabel: 'Clear text',
    recordingSignsLabel:
        'Recording signs… sign each word clearly, one after another',
    analyzingSignsLabel: 'Analyzing your signs…',
    spokenLabel: 'Spoken',
    signsCapturedLabel: 'Signs captured',
    replayLabel: 'Replay',
    cameraPermissionRequiredLabel:
        'Camera permission is required to record signs.',
    signCaptureFailedLabel: 'Could not analyze signs. Please try again.',
    signCaptureRateLimitedLabel:
        'Sign analysis is busy right now. Please wait a minute and try again.',
    signCaptureModelUnavailableLabel:
        'Sign analysis is temporarily unavailable. Please try again later.',
    signCaptureServiceUnavailableLabel:
        'Sign analysis server is unavailable. Please try again shortly.',
    signCaptureNotConfiguredLabel:
        'Sign analysis is not configured yet. Please try again later.',
    signCaptureUnauthorizedLabel:
        'Sign analysis could not be authorized. Please try again later.',
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
    callEmergencyConfirmTitle: 'Call emergency services?',
    callEmergencyConfirmBody:
        'SignBridge will automatically call 112. Allow phone permission if asked.',
    sosConfirmTitle: 'Activate SOS?',
    sosConfirmBody:
        'SignBridge will speak an emergency message, then automatically call 112.',
    emergencyCancelLabel: 'Cancel',
    emergencyConfirmLabel: 'Call now',
    emergencyCallFailedLabel: 'Could not place the emergency call.',
    sosCountdownTitle: 'Calling emergency services',
    sosCountdownBody:
        'Calling 112 automatically. Tap Cancel to stop.',
    sosCountdownCancelLabel: 'Cancel',
    emergencyPhonePermissionRequiredLabel:
        'Phone permission is required to auto-call emergency services.',
    signRecordingTooShortLabel:
        'Hold record for at least 2 seconds while signing your full phrase.',
    signRecordingEmptyLabel:
        'Recording was empty. Try signing clearly for 2–3 seconds.',
    signNoSignsDetectedLabel:
        'No signs detected. Try signing clearly for 2–3 seconds.',
    aboutSection: 'ABOUT',
    appLabel: 'App',
    versionLabel: 'Version',
    footerCopyright: '© 2026 adesso India',
    languageChangeConfirmTitle: 'Change language?',
    languageChangeConfirmLabel: 'Change',
    languageChangeConfirmListeningBody:
        'This will stop listening and clear the current caption.',
    languageChangeConfirmRecordingBody:
        'This will stop recording and discard the video.',
    languageChangeBlockedAnalyzingLabel:
        'Sign analysis is in progress. Please wait.',
    languageChangeBlockedEmergencyLabel:
        'Finish the emergency action before changing language.',
    languageChangedSnackbar: 'Language changed to {language}',
  ),
  'ML': HomeUiCopy(
    emptyStateMessage:
        'ഇതുവരെ സംഭാഷണമില്ല.\nആരംഭിക്കാൻ താഴെയുള്ള ബട്ടണുകൾ ഉപയോഗിക്കുക.',
    tapToListen: 'കേൾക്കാൻ ടാപ്പ് ചെയ്യുക',
    tapToSign: 'സൈൻ ചെയ്യാൻ ടാപ്പ് ചെയ്യുക',
    tapToTranslate: 'വിവർത്തനം ചെയ്യാൻ ടാപ്പ് ചെയ്യുക',
    tapToStop: 'നിർത്താൻ ടാപ്പ് ചെയ്യുക',
    sendCaptionLabel: 'അയയ്ക്കുക',
    flipCameraLabel: 'ക്യാമറ തിരിക്കുക',
    clearCaptionLabel: 'ടെക്സ്റ്റ് മായ്ക്കുക',
    recordingSignsLabel:
        'സൈനുകൾ റെക്കോർഡ് ചെയ്യുന്നു… മുഴുവൻ വാചകം സൈൻ ചെയ്യുക (2–3 സെക്ക)',
    analyzingSignsLabel: 'നിങ്ങളുടെ സൈനുകൾ വിശകലനം ചെയ്യുന്നു…',
    spokenLabel: 'സംസാരിച്ചു',
    signsCapturedLabel: 'കൈപ്പിടിച്ച സൈനുകൾ',
    replayLabel: 'വീണ്ടും കേൾക്കുക',
    cameraPermissionRequiredLabel:
        'സൈനുകൾ റെക്കോർഡ് ചെയ്യാൻ ക്യാമറ അനുമതി ആവശ്യമാണ്.',
    signCaptureFailedLabel:
        'സൈനുകൾ വിശകലനം ചെയ്യാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക.',
    signCaptureRateLimitedLabel:
        'സൈൻ വിശകലനം ഇപ്പോൾ തിരക്കിലാണ്. ഒരു മിനിറ്റ് കാത്തിരുന്ന് വീണ്ടും ശ്രമിക്കുക.',
    signCaptureModelUnavailableLabel:
        'സൈൻ വിശകലനം താൽക്കാലികമായി ലഭ്യമല്ല. പിന്നീട് വീണ്ടും ശ്രമിക്കുക.',
    signCaptureServiceUnavailableLabel:
        'സൈൻ വിശകലന സർവർ ലഭ്യമല്ല. കുറച്ച് കഴിഞ്ഞ് വീണ്ടും ശ്രമിക്കുക.',
    signCaptureNotConfiguredLabel:
        'സൈൻ വിശകലനം ഇതുവരെ ക്രമീകരിച്ചിട്ടില്ല. പിന്നീട് വീണ്ടും ശ്രമിക്കുക.',
    signCaptureUnauthorizedLabel:
        'സൈൻ വിശകലനം അംഗീകരിക്കാൻ കഴിഞ്ഞില്ല. വീണ്ടും ശ്രമിക്കുക.',
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
    callEmergencyConfirmTitle: 'അടിയന്തര സേവനങ്ങളിലേക്ക് വിളിക്കണോ?',
    callEmergencyConfirmBody:
        'SignBridge 112-ലേക്ക് സ്വയമേവ വിളിക്കും. ചോദിച്ചാൽ ഫോൺ അനുമതി അനുവദിക്കുക.',
    sosConfirmTitle: 'SOS സജീവമാക്കണോ?',
    sosConfirmBody:
        'SignBridge ഒരു അടിയന്തര സന്ദേശം പറയും, തുടർന്ന് 112-ലേക്ക് സ്വയമേവ വിളിക്കും.',
    emergencyCancelLabel: 'റദ്ദാക്കുക',
    emergencyConfirmLabel: 'ഇപ്പോൾ വിളിക്കുക',
    emergencyCallFailedLabel: 'അടിയന്തര കോൾ ചെയ്യാൻ കഴിഞ്ഞില്ല.',
    sosCountdownTitle: 'അടിയന്തര സേവനങ്ങളിലേക്ക് വിളിക്കുന്നു',
    sosCountdownBody: '112-ലേക്ക് സ്വയമേവ വിളിക്കും. നിർത്താൻ റദ്ദാക്കുക അമർത്തുക.',
    sosCountdownCancelLabel: 'റദ്ദാക്കുക',
    emergencyPhonePermissionRequiredLabel:
        'അടിയന്തര കോൾ ചെയ്യാൻ ഫോൺ അനുമതി ആവശ്യമാണ്.',
    signRecordingTooShortLabel:
        'സൈൻ ചെയ്യുമ്പോൾ റെക്കോർഡ് ബട്ടൺ കുറഞ്ഞത് 2 സെക്കന്റ് hold ചെയ്യുക.',
    signRecordingEmptyLabel:
        'റെക്കോർഡിംഗ് empty ആയിരുന്നു. 2–3 സെക്കന്റ് clearly സൈൻ ചെയ്ത് വീണ്ടും ശ്രമിക്കുക.',
    signNoSignsDetectedLabel:
        'സൈനുകൾ കണ്ടെത്തിയില്ല. 2–3 സെക്കന്റ് clearly സൈൻ ചെയ്ത് വീണ്ടും ശ്രമിക്കുക.',
    aboutSection: 'കുറിച്ച്',
    appLabel: 'ആപ്പ്',
    versionLabel: 'പതിപ്പ്',
    footerCopyright: '© 2026 adesso India',
    languageChangeConfirmTitle: 'ഭാഷ മാറ്റണോ?',
    languageChangeConfirmLabel: 'മാറ്റുക',
    languageChangeConfirmListeningBody:
        'ഇത് കേൾക്കൽ നിർത്തുകയും നിലവിലെ കാപ്ഷൻ മായ്ക്കുകയും ചെയ്യും.',
    languageChangeConfirmRecordingBody:
        'ഇത് റെക്കോർഡിംഗ് നിർത്തുകയും വീഡിയോ നിരസിക്കുകയും ചെയ്യും.',
    languageChangeBlockedAnalyzingLabel:
        'സൈൻ വിശകലനം നടക്കുന്നു. ദയവായി കാത്തിരിക്കുക.',
    languageChangeBlockedEmergencyLabel:
        'ഭാഷ മാറ്റുന്നതിന് മുമ്പ് അടിയന്തര പ്രവർത്തനം പൂർത്തിയാക്കുക.',
    languageChangedSnackbar: 'ഭാഷ {language}-ലേക്ക് മാറ്റി',
  ),
  'HI': HomeUiCopy(
    emptyStateMessage:
        'अभी तक कोई बातचीत नहीं।\nशुरू करने के लिए नीचे दिए बटन का उपयोग करें।',
    tapToListen: 'सुनने के लिए टैप करें',
    tapToSign: 'साइन करने के लिए टैप करें',
    tapToTranslate: 'अनुवाद के लिए टैप करें',
    tapToStop: 'रोकने के लिए टैप करें',
    sendCaptionLabel: 'भेजें',
    flipCameraLabel: 'कैमरा पलटें',
    clearCaptionLabel: 'टेक्स्ट साफ़ करें',
    recordingSignsLabel:
        'साइन रिकॉर्ड हो रहे हैं… पूरा वाक्य साइन करें (2–3 सेक)',
    analyzingSignsLabel: 'आपके साइन का विश्लेषण हो रहा है…',
    spokenLabel: 'बोला गया',
    signsCapturedLabel: 'पहचाने गए साइन',
    replayLabel: 'फिर से सुनें',
    cameraPermissionRequiredLabel:
        'साइन रिकॉर्ड करने के लिए कैमरा अनुमति आवश्यक है।',
    signCaptureFailedLabel:
        'साइन का विश्लेषण नहीं हो सका। कृपया पुनः प्रयास करें।',
    signCaptureRateLimitedLabel:
        'साइन विश्लेषण अभी व्यस्त है। एक मिनट रुककर पुनः प्रयास करें।',
    signCaptureModelUnavailableLabel:
        'साइन विश्लेषण अस्थायी रूप से उपलब्ध नहीं है। बाद में पुनः प्रयास करें।',
    signCaptureServiceUnavailableLabel:
        'साइन विश्लेषण सर्वर उपलब्ध नहीं है। थोड़ी देर बाद पुनः प्रयास करें।',
    signCaptureNotConfiguredLabel:
        'साइन विश्लेषण अभी कॉन्फ़िगर नहीं है। बाद में पुनः प्रयास करें।',
    signCaptureUnauthorizedLabel:
        'साइन विश्लेषण अधिकृत नहीं हो सका। पुनः प्रयास करें।',
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
    callEmergencyConfirmTitle: 'आपातकालीन सेवाओं को कॉल करें?',
    callEmergencyConfirmBody:
        'SignBridge स्वचालित रूप से 112 पर कॉल करेगा। पूछे जाने पर फ़ोन अनुमति दें।',
    sosConfirmTitle: 'SOS सक्रिय करें?',
    sosConfirmBody:
        'SignBridge एक आपातकालीन संदेश बोलेगा, फिर स्वचालित रूप से 112 पर कॉल करेगा।',
    emergencyCancelLabel: 'रद्द करें',
    emergencyConfirmLabel: 'अभी कॉल करें',
    emergencyCallFailedLabel: 'आपातकालीन कॉल नहीं हो सकी।',
    sosCountdownTitle: 'आपातकालीन सेवाओं को कॉल किया जा रहा है',
    sosCountdownBody: '112 पर स्वचालित कॉल। रोकने के लिए रद्द करें दबाएँ।',
    sosCountdownCancelLabel: 'रद्द करें',
    emergencyPhonePermissionRequiredLabel:
        'स्वचालित आपातकालीन कॉल के लिए फ़ोन अनुमति आवश्यक है।',
    signRecordingTooShortLabel:
        'पूरा वाक्य साइन करते हुए रिकॉर्ड कम से कम 2 सेकंड दबाए रखें।',
    signRecordingEmptyLabel:
        'रिकॉर्डिंग खाली थी। 2–3 सेकंड स्पष्ट साइन करके फिर कोशिश करें।',
    signNoSignsDetectedLabel:
        'कोई साइन नहीं मिला। 2–3 सेकंड स्पष्ट साइन करके फिर कोशिश करें।',
    aboutSection: 'के बारे में',
    appLabel: 'ऐप',
    versionLabel: 'संस्करण',
    footerCopyright: '© 2026 adesso India',
    languageChangeConfirmTitle: 'भाषा बदलें?',
    languageChangeConfirmLabel: 'बदलें',
    languageChangeConfirmListeningBody:
        'इससे सुनना बंद हो जाएगा और वर्तमान कैप्शन साफ़ हो जाएगा।',
    languageChangeConfirmRecordingBody:
        'इससे रिकॉर्डिंग बंद हो जाएगी और वीडियो हट जाएगा।',
    languageChangeBlockedAnalyzingLabel:
        'साइन विश्लेषण चल रहा है। कृपया प्रतीक्षा करें।',
    languageChangeBlockedEmergencyLabel:
        'भाषा बदलने से पहले आपातकालीन कार्रवाई पूरी करें।',
    languageChangedSnackbar: 'भाषा {language} में बदली',
  ),
  'TA': HomeUiCopy(
    emptyStateMessage:
        'இன்னும் உரையாடல் இல்லை.\nதொடங்க கீழுள்ள பொத்தான்களைப் பயன்படுத்தவும்.',
    tapToListen: 'கேட்க தட்டவும்',
    tapToSign: 'சைகை செய்ய தட்டவும்',
    tapToTranslate: 'மொழிபெயர்க்க தட்டவும்',
    tapToStop: 'நிறுத்த தட்டவும்',
    sendCaptionLabel: 'அனுப்பு',
    flipCameraLabel: 'கேமராவை மாற்று',
    clearCaptionLabel: 'உரையை அழிக்க',
    recordingSignsLabel:
        'சைகைகள் பதிவு செய்யப்படுகின்றன… முழு வாக்கியம் சைகை செய்யுங்கள் (2–3 வி)',
    analyzingSignsLabel: 'உங்கள் சைகைகள் பகுப்பாய்வு செய்யப்படுகின்றன…',
    spokenLabel: 'பேசப்பட்டது',
    signsCapturedLabel: 'பிடிப்பட்ட சைகைகள்',
    replayLabel: 'மீண்டும் கேளுங்கள்',
    cameraPermissionRequiredLabel: 'சைகைகளை பதிவு செய்ய கேமரா அனுமதி தேவை.',
    signCaptureFailedLabel:
        'சைகைகளை பகுப்பாய்வு செய்ய முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
    signCaptureRateLimitedLabel:
        'சைகை பகுப்பாய்வு இப்போது பிஸியாக உள்ளது. ஒரு நிமிடம் காத்திருந்து மீண்டும் முயற்சிக்கவும்.',
    signCaptureModelUnavailableLabel:
        'சைகை பகுப்பாய்வு தற்காலிகமாக கிடைக்கவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
    signCaptureServiceUnavailableLabel:
        'சைகை பகுப்பாய்வு சேவையகம் கிடைக்கவில்லை. சிறிது நேரம் கழித்து மீண்டும் முயற்சிக்கவும்.',
    signCaptureNotConfiguredLabel:
        'சைகை பகுப்பாய்வு இன்னும் அமைக்கப்படவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
    signCaptureUnauthorizedLabel:
        'சைகை பகுப்பாய்வை அங்கீகரிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
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
    callEmergencyConfirmTitle: 'அவசர சேவைகளை அழைக்கவா?',
    callEmergencyConfirmBody:
        'SignBridge தானாக 112-க்கு அழைக்கும். கேட்கப்பட்டால் தொலைபேசி அனுமதியை வழங்கவும்.',
    sosConfirmTitle: 'SOS ஐ செயல்படுத்தவா?',
    sosConfirmBody:
        'SignBridge ஒரு அவசர செய்தியை பேசும், பின்னர் தானாக 112-க்கு அழைக்கும்.',
    emergencyCancelLabel: 'ரத்து செய்',
    emergencyConfirmLabel: 'இப்போது அழை',
    emergencyCallFailedLabel: 'அவசர அழைப்பை இணைக்க முடியவில்லை.',
    sosCountdownTitle: 'அவசர சேவைகளை அழைக்கிறது',
    sosCountdownBody:
        '112-க்கு தானாக அழைக்கப்படும். நிறுத்த ரத்து செய் அழுத்தவும்.',
    sosCountdownCancelLabel: 'ரத்து செய்',
    emergencyPhonePermissionRequiredLabel:
        'தானியங்கி அவசர அழைப்புக்கு தொலைபேசி அனுமதி தேவை.',
    signRecordingTooShortLabel:
        'முழு வாக்கியம் சைகை செய்து கொண்டே ரெக்கார்டை குறைந்தது 2 வினாடிகள் அழுத்தி வைத்திருங்கள்.',
    signRecordingEmptyLabel:
        'பதிவு காலியாக இருந்தது. 2–3 வினாடிகள் தெளிவாக சைகை செய்து மீண்டும் முயற்சிக்கவும்.',
    signNoSignsDetectedLabel:
        'சைகைகள் கண்டறியப்படவில்லை. 2–3 வினாடிகள் தெளிவாக சைகை செய்து மீண்டும் முயற்சிக்கவும்.',
    aboutSection: 'பற்றி',
    appLabel: 'பயன்பாடு',
    versionLabel: 'பதிப்பு',
    footerCopyright: '© 2026 adesso India',
    languageChangeConfirmTitle: 'மொழியை மாற்றவா?',
    languageChangeConfirmLabel: 'மாற்று',
    languageChangeConfirmListeningBody:
        'இது கேட்பதை நிறுத்தி தற்போதைய தலைப்பை அழிக்கும்.',
    languageChangeConfirmRecordingBody:
        'இது பதிவை நிறுத்தி வீடியோவை நிராகரிக்கும்.',
    languageChangeBlockedAnalyzingLabel:
        'சைகை பகுப்பாய்வு நடந்து கொண்டிருக்கிறது. காத்திருக்கவும்.',
    languageChangeBlockedEmergencyLabel:
        'மொழியை மாற்றுவதற்கு முன் அவசர செயலை முடிக்கவும்.',
    languageChangedSnackbar: 'மொழி {language}-க்கு மாற்றப்பட்டது',
  ),
};

HomeUiCopy homeUiCopyFor(String languageCode) {
  return _homeUiCopyByLanguage[languageCode] ?? _homeUiCopyByLanguage['ENG']!;
}
