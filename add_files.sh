#!/bin/bash
# Xcode에서 프로젝트를 닫은 후 실행하세요

# UUID 생성 함수
generate_uuid() {
    uuidgen | tr '[:lower:]' '[:upper:]' | tr -d '-' | cut -c1-24
}

# 파일 경로
MARKDOWN_PARSER="WeekAheadTodo/Services/MarkdownParser.swift"
IMPORT_VIEW="WeekAheadTodo/Views/ImportView.swift"

echo "새 파일들을 Xcode 프로젝트에 추가하려면:"
echo "1. Xcode를 종료하세요"
echo "2. Xcode Project Navigator에서:"
echo "   - Services 폴더를 우클릭 → Add Files to WeekAheadTodo"
echo "   - $MARKDOWN_PARSER 선택"
echo "   - Views 폴더를 우클릭 → Add Files to WeekAheadTodo"
echo "   - $IMPORT_VIEW 선택"
echo ""
echo "또는 Finder에서 파일을 드래그해서 Xcode의 해당 폴더에 드롭하세요."
