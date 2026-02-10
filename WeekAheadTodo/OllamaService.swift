//
//  OllamaService.swift
//  WeekAheadTodo
//
//  Ollama API를 통한 메일 분석 서비스
//

import Foundation

/// 메일 분석 결과
struct MailAnalysisResult: Codable, Identifiable {
    let id = UUID()
    var events: [ExtractedEvent]
    var todos: [ExtractedTodo]
    var summary: String
    
    enum CodingKeys: String, CodingKey {
        case events, todos, summary
    }
}

/// 추출된 일정
struct ExtractedEvent: Codable, Identifiable {
    let id = UUID()
    var title: String
    var date: String
    var time: String?
    var location: String?
    var duration: Int?  // 분 단위
    
    enum CodingKeys: String, CodingKey {
        case title, date, time, location, duration
    }
}

/// 추출된 할일
struct ExtractedTodo: Codable, Identifiable {
    let id = UUID()
    var title: String
    var deadline: String?
    var priority: String?  // high, medium, low
    
    enum CodingKeys: String, CodingKey {
        case title, deadline, priority
    }
}

/// Ollama API 서비스
@MainActor
class OllamaService: ObservableObject {
    
    static let shared = OllamaService()
    
    @Published var isAnalyzing = false
    @Published var lastError: String?
    @Published var availableModels: [String] = []
    
    private let baseURL = "http://localhost:11434"
    private var currentModel = "qwen2.5:7b"
    
    private init() {}
    
    // MARK: - 모델 관리
    
    /// 사용 가능한 모델 목록 가져오기
    func fetchModels() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["name"] as? String }
                print("📦 [Ollama] 모델 목록: \(availableModels)")
            }
        } catch {
            print("❌ [Ollama] 모델 목록 가져오기 실패: \(error)")
        }
    }
    
    /// 모델 변경
    func setModel(_ model: String) {
        currentModel = model
        print("🔄 [Ollama] 모델 변경: \(model)")
    }
    
    // MARK: - 메일 분석
    
    /// 메일 내용 분석
    func analyzeMail(_ mail: MailMessage) async -> MailAnalysisResult? {
        isAnalyzing = true
        lastError = nil
        
        let prompt = buildAnalysisPrompt(mail)
        
        do {
            let response = try await sendRequest(prompt: prompt)
            let result = parseAnalysisResponse(response)
            isAnalyzing = false
            return result
        } catch {
            print("❌ [Ollama] 분석 실패: \(error)")
            lastError = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func buildAnalysisPrompt(_ mail: MailMessage) -> String {
        """
        다음 이메일을 분석해서 일정과 할일을 추출해주세요.
        
        발신자: \(mail.sender)
        제목: \(mail.subject)
        날짜: \(mail.date.formatted())
        내용:
        \(mail.body.prefix(2000))
        
        다음 JSON 형식으로만 응답해주세요 (다른 설명 없이):
        {
            "events": [
                {"title": "일정 제목", "date": "2026-02-15", "time": "14:00", "location": "장소", "duration": 60}
            ],
            "todos": [
                {"title": "할일 내용", "deadline": "2026-02-20", "priority": "high"}
            ],
            "summary": "이 메일의 핵심 요약 (1-2문장)"
        }
        
        일정이나 할일이 없으면 빈 배열로 응답하세요.
        """
    }
    
    private func sendRequest(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": currentModel,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.1  // 더 정확한 응답을 위해 낮은 temperature
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🤖 [Ollama] 분석 요청 중...")
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? String else {
            throw OllamaError.invalidResponse
        }
        
        print("✅ [Ollama] 응답 받음: \(response.prefix(200))...")
        return response
    }
    
    private func parseAnalysisResponse(_ response: String) -> MailAnalysisResult? {
        // JSON 부분만 추출
        var jsonString = response
        
        // ```json ... ``` 형식 처리
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ [Ollama] JSON 변환 실패")
            return nil
        }
        
        do {
            let result = try JSONDecoder().decode(MailAnalysisResult.self, from: data)
            print("✅ [Ollama] 분석 완료: 일정 \(result.events.count)개, 할일 \(result.todos.count)개")
            return result
        } catch {
            print("❌ [Ollama] JSON 파싱 실패: \(error)")
            // 기본 결과 반환
            return MailAnalysisResult(events: [], todos: [], summary: "분석 실패")
        }
    }
}

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "잘못된 URL"
        case .invalidResponse: return "잘못된 응답"
        case .modelNotFound: return "모델을 찾을 수 없음"
        }
    }
}
