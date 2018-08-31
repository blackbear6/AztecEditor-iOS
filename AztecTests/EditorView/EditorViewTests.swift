import XCTest
@testable import Aztec

class EditorViewTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    // MARK: - EditorView Properties
    
    func testContentInset() {
        let font = UIFont.systemFont(ofSize: 14)
        let editorView = Aztec.EditorView(
            defaultFont: font,
            defaultHTMLFont: font,
            defaultParagraphStyle: ParagraphStyle(),
            defaultMissingImage: UIImage())
        let insets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        editorView.contentInset = insets
        
        XCTAssertEqual(editorView.richTextView.contentInset, insets)
        XCTAssertEqual(editorView.htmlTextView.contentInset, insets)
    }
    
    func testContentOffset() {
        let font = UIFont.systemFont(ofSize: 14)
        let editorView = Aztec.EditorView(
            defaultFont: font,
            defaultHTMLFont: font,
            defaultParagraphStyle: ParagraphStyle(),
            defaultMissingImage: UIImage())
        let offset = CGPoint(x: 20, y: 30)
        
        editorView.contentOffset = offset
        
        XCTAssertEqual(editorView.richTextView.contentOffset, offset)
        XCTAssertEqual(editorView.htmlTextView.contentOffset, offset)
    }
    
    func testScrollIndicatorInsets() {
        let font = UIFont.systemFont(ofSize: 14)
        let editorView = Aztec.EditorView(
            defaultFont: font,
            defaultHTMLFont: font,
            defaultParagraphStyle: ParagraphStyle(),
            defaultMissingImage: UIImage())
        let insets = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        
        editorView.scrollIndicatorInsets = insets
        
        XCTAssertEqual(editorView.richTextView.scrollIndicatorInsets, insets)
        XCTAssertEqual(editorView.htmlTextView.scrollIndicatorInsets, insets)
    }
    
    func testEditingModeAndActiveView() {
        let font = UIFont.systemFont(ofSize: 14)
        let editorView = Aztec.EditorView(
            defaultFont: font,
            defaultHTMLFont: font,
            defaultParagraphStyle: ParagraphStyle(),
            defaultMissingImage: UIImage())
        
        XCTAssertEqual(editorView.editingMode, .richText)
        XCTAssertEqual(editorView.activeView, editorView.richTextView)
        
        editorView.toggleEditingMode()
        XCTAssertEqual(editorView.editingMode, .html)
        XCTAssertEqual(editorView.activeView, editorView.htmlTextView)
        
        editorView.toggleEditingMode()
        XCTAssertEqual(editorView.editingMode, .richText)
        XCTAssertEqual(editorView.activeView, editorView.richTextView)
    }
}
