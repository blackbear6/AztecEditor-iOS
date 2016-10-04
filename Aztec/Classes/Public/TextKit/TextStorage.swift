import Foundation
import UIKit

protocol TextStorageImageProvider {
    func storage(storage: TextStorage, attachment: TextAttachment, imageForURL url: NSURL, onSuccess success: (UIImage) -> (), onFailure failure: () -> ()) -> UIImage
    func storage(storage: TextStorage, missingImageForAttachment: TextAttachment) -> UIImage
}

/// Custom NSTextStorage
///
public class TextStorage: NSTextStorage {

    typealias ElementNode = Libxml2.ElementNode
    typealias TextNode = Libxml2.TextNode
    typealias RootNode = Libxml2.RootNode

    // Represents the possible HTML types that the TextStorage element can handle
    enum ElementTypes: String {
        case bold = "b"
        case italic = "em"
        case striketrough = "s"
        case underline = "u"
        case link = "a"

        // Some HTML elements can have more than one valid representation so we list all possible variations here.
        var equivalentNames: [String] {
            get {
                switch self {
                case .bold: return [self.rawValue, "strong"]
                case .italic: return [self.rawValue, "em"]
                case .striketrough: return [self.rawValue, "strike"]
                case .underline: return [self.rawValue, "u"]
                case .link: return [self.rawValue]
                }
            }
        }
    }

    private var textStore = NSMutableAttributedString(string: "", attributes: nil)

    private var rootNode: RootNode = {
        return RootNode(children: [TextNode(text: "")])
    }()

    // MARK: - NSTextStorage

    override public var string: String {
        return textStore.string
    }

    // MARK: - Attachments

    var imageProvider: TextStorageImageProvider?

    public func TextAttachments() -> [TextAttachment] {
        let range = NSMakeRange(0, length)
        var attachments = [TextAttachment]()
        enumerateAttribute(NSAttachmentAttributeName, inRange: range, options: []) { (object, range, stop) in
            if let attachment = object as? TextAttachment {
                attachments.append(attachment)
            }
        }

        return attachments
    }

    public func range(forAttachment attachment: TextAttachment) -> NSRange? {

        var range: NSRange?

        textStore.enumerateAttachmentsOfType(TextAttachment.self) { (currentAttachment, currentRange, stop) in
            if attachment == currentAttachment {
                range = currentRange
                stop.memory = true
            }
        }

        return range
    }

    // MARK: - Overriden Methods

    override public func attributesAtIndex(location: Int, effectiveRange range: NSRangePointer) -> [String : AnyObject] {
        return textStore.attributesAtIndex(location, effectiveRange: range)
    }

    override public func replaceCharactersInRange(range: NSRange, withString str: String) {
        beginEditing()
        textStore.replaceCharactersInRange(range, withString: str)
        rootNode.replaceCharacters(inRange: range, withString: str, inheritStyle: true)
        endEditing()
        
        edited(.EditedCharacters, range: range, changeInLength: str.characters.count - range.length)
    }
    
    override public func replaceCharactersInRange(range: NSRange, withAttributedString attrString: NSAttributedString) {
        beginEditing()
        textStore.replaceCharactersInRange(range, withAttributedString: attrString)
        rootNode.replaceCharacters(inRange: range, withString: attrString.string, inheritStyle: false)
        
        // remove all styles for the specified range here!
        
        let finalRange = NSRange(location: range.location, length: attrString.length)
        copyStylesToDOM(spanning: finalRange)
        endEditing()
        
        edited([.EditedAttributes, .EditedCharacters], range: range, changeInLength: attrString.string.characters.count - range.length)
    }

    override public func setAttributes(attrs: [String : AnyObject]?, range: NSRange) {
        beginEditing()
        textStore.setAttributes(attrs, range: range)
        endEditing()

        edited(.EditedAttributes, range: range, changeInLength: 0)
    }

    // MARK: - Styles: Synchronization with DOM

    /// Copies all styles in the specified range to the DOM.
    ///
    /// - Parameters:
    ///     - range: the range from which to take the styles to copy.
    ///
    private func copyStylesToDOM(spanning range: NSRange) {

        let options = NSAttributedStringEnumerationOptions(rawValue: 0)

        textStore.enumerateAttributesInRange(range, options: options) { (attributes, range, stop) in
            // Edit attributes

            for (key, value) in attributes {
                switch (key) {
                case NSFontAttributeName:
                    copyFontAttributesToDOM(spanning: range, attributeValue: value)
                case NSStrikethroughStyleAttributeName:
                    copyStrikethroughStyleToDOM(spanning: range, attributeValue: value)
                case NSUnderlineStyleAttributeName:
                    copyUnderlineStyleToDOM(spanning: range, attributeValue: value)
                default:
                    break
                }
            }
        }
    }
    
    private func copyFontAttributesToDOM(spanning range: NSRange, attributeValue value: AnyObject) {
        
        guard let font = value as? UIFont else {
            assertionFailure("Was expecting a UIFont object as the value for the font attribute.")
            return
        }
        
        copyFontAttributesToDOM(spanning: range, font: font)
    }
    
    private func copyFontAttributesToDOM(spanning range: NSRange, font: UIFont) {
        
        let fontTraits = font.fontDescriptor().symbolicTraits
        
        if fontTraits.contains(.TraitBold) {
            enableBoldInDOM(range)
        }
        
        if fontTraits.contains(.TraitItalic) {
            enableItalicInDOM(range)
        }
    }
    
    private func copyStrikethroughStyleToDOM(spanning range: NSRange, attributeValue value: AnyObject) {
        
        guard let intValue = value as? Int else {
            assertionFailure("The strikethrough style is always expected to be an Int.")
            return
        }
        
        guard let style = NSUnderlineStyle(rawValue: intValue) else {
            assertionFailure("The strikethrough style value is not-known.")
            return
        }
        
        copyStrikethroughStyleToDOM(spanning: range, style: style)
    }
    
    private func copyStrikethroughStyleToDOM(spanning range: NSRange, style: NSUnderlineStyle) {
        
        switch (style) {
        case .StyleSingle:
            enableStrikethroughInDOM(range)
        default:
            // We don't support anything more than single-line strikethrough for now
            break
        }
    }
    
    private func copyUnderlineStyleToDOM(spanning range: NSRange, attributeValue value: AnyObject) {
        
        guard let intValue = value as? Int else {
            assertionFailure("The underline style is always expected to be an Int.")
            return
        }
        
        guard let style = NSUnderlineStyle(rawValue: intValue) else {
            assertionFailure("The underline style value is not-known.")
            return
        }
        
        copyUnderlineStyleToDOM(spanning: range, style: style)
    }
    
    private func copyUnderlineStyleToDOM(spanning range: NSRange, style: NSUnderlineStyle) {
        
        switch (style) {
        case .StyleSingle:
            enableUnderlineInDOM(range)
        default:
            // We don't support anything more than single-line underline for now
            break
        }
    }
    
    // MARK: - Styles: Toggling

    func toggleBold(range: NSRange) {

        let enable = !fontTrait(.TraitBold, spansRange: range)

        modifyTrait(.TraitBold, range: range, enable: enable)

        if enable {
            enableBoldInDOM(range)
        } else {
            disableBoldInDom(range)
        }
    }

    func toggleItalic(range: NSRange) {

        let enable = !fontTrait(.TraitItalic, spansRange: range)

        modifyTrait(.TraitItalic, range: range, enable: enable)

        if enable {
            enableItalicInDOM(range)
        } else {
            disableItalicInDom(range)
        }
    }

    func toggleStrikethrough(range: NSRange) {
        toggleAttribute(NSStrikethroughStyleAttributeName, value: NSUnderlineStyle.StyleSingle.rawValue, range: range, onEnable: enableStrikethroughInDOM, onDisable: disableStrikethroughInDom)
    }

    /// Toggles underline for the specified range.
    ///
    /// - Note: A better name would have been `toggleUnderline` but it was clashing with a method
    ///     in the parent class.
    ///
    /// - Note: This is a bit tricky as we can collide with a link style.  We'll want to check for
    ///     that and correct the style if necessary.
    ///
    /// - Parameters:
    ///     - range: the range to toggle the style of.
    ///
    func toggleUnderlineForRange(range: NSRange) {
        toggleAttribute(NSUnderlineStyleAttributeName, value: NSUnderlineStyle.StyleSingle.rawValue, range: range, onEnable: enableUnderlineInDOM, onDisable: disableUnderlineInDom)
    }

    func setLink(url: NSURL, forRange range: NSRange) {
        var effectiveRange = range
        if attribute(NSLinkAttributeName, atIndex: range.location, effectiveRange: &effectiveRange) != nil {
            //if there was a link there before let's remove it
            removeAttribute(NSLinkAttributeName, range: effectiveRange)
        } else {
            //if a link was not there we are just going to add it to the provided range
            effectiveRange = range
        }
        
        addAttribute(NSLinkAttributeName, value: url, range: effectiveRange)
        rootNode.wrapChildren(
            intersectingRange: effectiveRange,
            inNodeNamed: ElementTypes.link.rawValue,
            withAttributes: [Libxml2.StringAttribute(name:"href", value: url.absoluteString!)],
            equivalentElementNames: ElementTypes.link.equivalentNames)
    }

    func removeLink(inRange range: NSRange){
        var effectiveRange = range
        if attribute(NSLinkAttributeName, atIndex: range.location, effectiveRange: &effectiveRange) != nil {
            //if there was a link there before let's remove it
            removeAttribute(NSLinkAttributeName, range: effectiveRange)
            rootNode.unwrap(range: effectiveRange, fromElementsNamed: ["a"])
        }
    }


    private func toggleAttribute(attributeName: String, value: AnyObject, range: NSRange, onEnable: (NSRange) -> Void, onDisable: (NSRange) -> Void) {

        var effectiveRange = NSRange()
        let enable = attribute(attributeName, atIndex: range.location, effectiveRange: &effectiveRange) == nil
            || !NSEqualRanges(range, effectiveRange)

        if enable {
            addAttribute(attributeName, value: value, range: range)
            onEnable(range)
        } else {
            removeAttribute(attributeName, range: range)
            onDisable(range)
        }
    }

    // MARK: - DOM

    private func disableBoldInDom(range: NSRange) {
        rootNode.unwrap(range: range, fromElementsNamed: ElementTypes.bold.equivalentNames)
    }

    private func disableItalicInDom(range: NSRange) {
        rootNode.unwrap(range: range, fromElementsNamed: ElementTypes.italic.equivalentNames)
    }

    private func disableStrikethroughInDom(range: NSRange) {
        rootNode.unwrap(range: range, fromElementsNamed: ElementTypes.striketrough.equivalentNames)
    }

    private func disableUnderlineInDom(range: NSRange) {
        rootNode.unwrap(range: range, fromElementsNamed: ElementTypes.underline.equivalentNames)
    }

    private func enableBoldInDOM(range: NSRange) {

        enableInDom(
            ElementTypes.bold.rawValue,
            inRange: range,
            equivalentElementNames: ElementTypes.bold.equivalentNames)
    }

    private func enableInDom(elementName: String, inRange range: NSRange, equivalentElementNames: [String]) {
        rootNode.wrapChildren(
            intersectingRange: range,
            inNodeNamed: elementName,
            withAttributes: [],
            equivalentElementNames: equivalentElementNames)
    }

    private func enableItalicInDOM(range: NSRange) {

        enableInDom(
            ElementTypes.italic.rawValue,
            inRange: range,
            equivalentElementNames: ElementTypes.italic.equivalentNames)
    }

    private func enableStrikethroughInDOM(range: NSRange) {

        enableInDom(
            ElementTypes.striketrough.rawValue,
            inRange: range,
            equivalentElementNames:  ElementTypes.striketrough.equivalentNames)
    }

    private func enableUnderlineInDOM(range: NSRange) {

        enableInDom(
            ElementTypes.underline.rawValue,
            inRange: range,
            equivalentElementNames:  ElementTypes.striketrough.equivalentNames)
    }

    // MARK: - HTML Interaction

    public func getHTML() -> String {
        let converter = Libxml2.Out.HTMLConverter()
        let html = converter.convert(rootNode)

        return html
    }

    func setHTML(html: String, withDefaultFontDescriptor defaultFontDescriptor: UIFontDescriptor) {

        let converter = HTMLToAttributedString(usingDefaultFontDescriptor: defaultFontDescriptor)
        let output: (rootNode: RootNode, attributedString: NSAttributedString)

        do {
            output = try converter.convert(html)
        } catch {
            fatalError("Could not convert the HTML.")
        }

        let originalLength = textStore.length
        textStore = NSMutableAttributedString(attributedString: output.attributedString)
        edited([.EditedAttributes, .EditedCharacters], range: NSRange(location: 0, length: originalLength), changeInLength: textStore.length - originalLength)        
        rootNode = output.rootNode

        enumerateAttachmentsOfType(TextAttachment.self) { [weak self] (attachment, range, stop) in
            self?.loadImageForAttachment(attachment, inRange: range)
        }
    }

    func loadImageForAttachment(attachment: TextAttachment, inRange range: NSRange) {

        guard let imageProvider = imageProvider else {
            fatalError("The image provider should've been set at this point.")
        }

        switch (attachment.kind) {
        case .RemoteImage(let url):
            attachment.image = imageProvider.storage(self, attachment: attachment, imageForURL: url, onSuccess: { [weak self] image in
                self?.downloadSuccess(attachment, url: url, image: image)
                }, onFailure: { [weak self] in
                    self?.downloadFailure(attachment)
            })
        case .RemoteImageDownloaded(_, let image):
            attachment.image = image

        default:
            attachment.image = imageProvider.storage(self, missingImageForAttachment: attachment)
        }

        invalidateLayoutForAttachment(attachment)
    }

    private func downloadSuccess(attachment: TextAttachment, url: NSURL, image: UIImage) {

        attachment.kind = .RemoteImageDownloaded(url: url, image: image)

        attachment.image = image
        invalidateLayoutForAttachment(attachment)
    }

    private func downloadFailure(attachment: TextAttachment) {
        guard let imageProvider = imageProvider else {
            fatalError("The image provider should've been set at this point.")
        }

        attachment.image = imageProvider.storage(self, missingImageForAttachment: attachment)
        invalidateLayoutForAttachment(attachment)
    }

    /// Invalidates the full layout.
    /// This is actually intended to invalidate the layout for a single attachment, but we've found
    /// crashing bugs when trying to figure out the correct range for an attachment.
    ///
    /// I'm temporarily commenting out the breaking code, but leaving it in to see if we can fix it.
    ///
    func invalidateLayoutForAttachment(attachment: TextAttachment) {

        guard layoutManagers.count > 0 else {
            fatalError("This storage should have at least one layout manager assigned.")
        }

        let layoutManager = layoutManagers[0]

        //if let range = range(forAttachment: attachment) {
            //layoutManager.invalidateLayoutForCharacterRange(range, actualCharacterRange: nil)
        layoutManager.invalidateLayoutForCharacterRange(NSRange(location: 0, length: textStore.length), actualCharacterRange: nil)
        //layoutManager.ensureLayoutForTextContainer(layoutManager.textContainers[0])
        //}
    }
}


/// Convenience extension to group font trait related methods.
///
public extension TextStorage
{


    /// Checks if the specified font trait exists at the specified character index.
    ///
    /// - Parameters:
    ///     - trait: A font trait.
    ///     - index: A character index.
    ///
    /// - Returns: True if found.
    ///
    public func fontTrait(trait: UIFontDescriptorSymbolicTraits, existsAtIndex index: Int) -> Bool {
        guard let attr = attribute(NSFontAttributeName, atIndex: index, effectiveRange: nil) else {
            return false
        }
        if let font = attr as? UIFont {
            return font.fontDescriptor().symbolicTraits.contains(trait)
        }
        return false
    }


    /// Checks if the specified font trait spans the specified NSRange.
    ///
    /// - Parameters:
    ///     - trait: A font trait.
    ///     - range: The NSRange to inspect
    ///
    /// - Returns: True if the trait spans the entire range.
    ///
    public func fontTrait(trait: UIFontDescriptorSymbolicTraits, spansRange range: NSRange) -> Bool {
        var spansRange = true

        // Assume we're removing the trait. If the trait is missing anywhere in the range assign it.
        enumerateAttribute(NSFontAttributeName,
                           inRange: range,
                           options: [],
                           usingBlock: { (object: AnyObject?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
                            guard let font = object as? UIFont else {
                                return
                            }
                            if !font.fontDescriptor().symbolicTraits.contains(trait) {
                                spansRange = false
                                stop.memory = true
                            }
        })

        return spansRange
    }


    /// Adds or removes the specified font trait within the specified range.
    ///
    /// - Parameters:
    ///     - trait: A font trait.
    ///     - range: The NSRange to inspect
    ///
    public func toggleFontTrait(trait: UIFontDescriptorSymbolicTraits, range: NSRange) {
        // Bail if nothing is selected
        if range.length == 0 {
            return
        }

        let enable = !fontTrait(trait, spansRange: range)

        modifyTrait(trait, range: range, enable: enable)
    }

    private func modifyTrait(trait: UIFontDescriptorSymbolicTraits, range: NSRange, enable: Bool) {

        enumerateAttribute(NSFontAttributeName,
                           inRange: range,
                           options: [],
                           usingBlock: { (object: AnyObject?, range: NSRange, stop: UnsafeMutablePointer<ObjCBool>) in
                            guard let font = object as? UIFont else {
                                return
                            }

                            var newTraits = font.fontDescriptor().symbolicTraits

                            if enable {
                                newTraits.insert(trait)
                            } else {
                                newTraits.remove(trait)
                            }

                            let descriptor = font.fontDescriptor().fontDescriptorWithSymbolicTraits(newTraits)
                            let newFont = UIFont(descriptor: descriptor!, size: font.pointSize)

                            self.beginEditing()
                            self.removeAttribute(NSFontAttributeName, range: range)
                            self.addAttribute(NSFontAttributeName, value: newFont, range: range)
                            self.endEditing()
        })
    }

}