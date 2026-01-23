tell application "Finder"
	set projectPath to POSIX file "/Users/leeo/Documents/code/WeekAheadTodo" as alias

	-- Services folder files
	set servicesFiles to {¬
		"WeekAheadTodo/Services/CalendarService.swift", ¬
		"WeekAheadTodo/Services/PatternDetectionService.swift"}

	-- Models folder files
	set modelsFiles to {¬
		"WeekAheadTodo/Models/CalendarEvent.swift", ¬
		"WeekAheadTodo/Models/RecurrencePattern.swift"}

	-- ViewModels folder files
	set viewModelsFiles to {¬
		"WeekAheadTodo/ViewModels/CalendarViewModel.swift"}

	-- Views folder files
	set viewsFiles to {¬
		"WeekAheadTodo/Views/CalendarIntegrationView.swift", ¬
		"WeekAheadTodo/Views/PatternReviewView.swift", ¬
		"WeekAheadTodo/Views/PatternDetailView.swift"}

	reveal folder projectPath
end tell

tell application "Xcode"
	activate
end tell

display dialog "Xcode와 Finder가 열렸습니다.

다음 단계를 진행해주세요:

1. Xcode 왼쪽 Project Navigator에서 'WeekAheadTodo' 폴더를 선택하세요
2. Finder에서 다음 폴더들을 Xcode로 드래그하세요:
   • Services 폴더
   • Views 폴더
3. 'Copy items if needed' 체크를 해제하고 Add 클릭

또는 수동으로:
• WeekAheadTodo 우클릭 → Add Files to WeekAheadTodo...
• Services, Views 폴더 선택
• Add 클릭

완료 후 ⌘+B로 빌드하세요!" buttons {"확인"} default button 1
