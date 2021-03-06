/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2018 Jean-David Gadina - www.imazing.com
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Cocoa

class MainWindowController: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSMenuDelegate
{
    @objc private dynamic var               selectedColor: ColorItem?
    @objc private dynamic var               hasVariant:    Bool          = false
    @objc public private( set ) dynamic var colors:        [ ColorItem ] = []
    
    public  var url:                URL?
    private var observations:       [ NSKeyValueObservation ] = []
    private var tableView:          NSTableView?
    private var colorNameTextField: NSTextField?
    private var searchField:        NSSearchField?
    
    @IBOutlet public var arrayController: NSArrayController?
    
    convenience init( colors: [ ColorItem ] )
    {
        self.init()
        
        self.colors = colors
    }
    
    override var windowNibName: NSNib.Name?
    {
        return NSNib.Name( NSStringFromClass( type( of: self ) ) )
    }
    
    override func windowDidLoad()
    {
        self.window?.title = ( self.url == nil ) ? "Untitled.colorset" : ( self.url!.path as NSString ).lastPathComponent
        
        guard let colorView = self.window?.contentView?.subviewWithIdentifier( "Color" ) as? ColorView else
        {
            return
        }
        
        guard let variantView = self.window?.contentView?.subviewWithIdentifier( "Variant" ) as? ColorView else
        {
            return
        }
        
        guard let controller = self.arrayController else
        {
            return
        }
        
        guard let tableView = self.window?.contentView?.subviewWithIdentifier( "TableView" ) as? NSTableView else
        {
            return
        }
        
        guard let colorNameTextField = self.window?.contentView?.subviewWithIdentifier( "ColorNameTextField" ) as? NSTextField else
        {
            return
        }
        
        guard let searchField = self.window?.contentView?.subviewWithIdentifier( "SearchField" ) as? NSSearchField else
        {
            return
        }
        
        self.tableView          = tableView
        self.colorNameTextField = colorNameTextField
        self.searchField        = searchField
        
        controller.sortDescriptors        = [ NSSortDescriptor( key: "name", ascending: true ) ]
        controller.selectsInsertedObjects = true
        
        colorView.bind(   NSBindingName( "color" ), to: self, withKeyPath: "selectedColor.color",   options: nil )
        variantView.bind( NSBindingName( "color" ), to: self, withKeyPath: "selectedColor.variant", options: nil )
            
        let o1 = controller.observe( \.selectionIndexes, options: .new )
        {
            ( o, c ) in
            
            guard let color = controller.selectedObjects.first as? ColorItem else
            {
                self.selectedColor = nil
                self.hasVariant    = false
                
                return
            }
            
            self.selectedColor = color
            self.hasVariant    = color.variant != nil
        }
        
        let o2 = self.observe( \.hasVariant, options: .new )
        {
            ( o, c ) in
            
            guard let color = controller.selectedObjects.first as? ColorItem else
            {
                return
            }
            
            if( self.hasVariant == false )
            {
                color.variant = nil
            }
            else if( self.hasVariant && color.variant == nil )
            {
                color.variant = color.color
            }
            
            color.hasVariant = self.hasVariant
        }
        
        self.observations.append( contentsOf: [ o1, o2 ] )
    }
    
    @IBAction public func performFindPanelAction( _ sender: Any? )
    {
        self.window?.makeFirstResponder( self.searchField )
    }
    
    @IBAction public func saveDocument( _ sender: Any? ) 
    {
        guard let url = self.url else
        {
            self.saveDocumentAs( sender )
            
            return
        }
        
        self.save( to: url )
    }
    
    @IBAction public func saveDocumentAs( _ sender: Any? ) 
    {
        guard let window = self.window else
        {
            return
        }
        
        let panel = NSSavePanel()
        
        panel.allowedFileTypes     = [ "colorset" ]
        panel.canCreateDirectories = true
        
        panel.beginSheetModal( for: window )
        {
            ( r ) in
            
            if( r != .OK )
            {
                return
            }
            
            guard let url = panel.url else
            {
                return
            }
            
            self.save( to: url )
            
            self.url           = url
            self.window?.title = ( self.url == nil ) ? "Untitled.colorset" : ( self.url!.path as NSString ).lastPathComponent
        }
    }
    
    public func save( to url: URL )
    {
        let set = ColorSet()
        
        for color in self.colors
        {
            set.addColor( color.color, variant: color.variant, forName: color.name )
        }
        
        do
        {
            try set.write( to: url )
        }
        catch let error as NSError
        {
            let alert = NSAlert( error: error )
            
            guard let window = self.window else
            {
                alert.runModal()
                
                return
            }
            
            alert.beginSheetModal( for: window, completionHandler: nil )
        }
    }
    
    @IBAction public func newColor( _ sender: Any? )
    {
        var i     = 0
        let color = ColorItem()
        
        for item in self.colors
        {
            if( item.name.hasPrefix( "Untitled" ) )
            {
                i += 1
            }
        }
        
        color.name = ( i > 0 ) ? "Untitled-" + String( describing: i ) : "Untitled"
        
        self.arrayController?.addObject( color )
        self.window?.makeFirstResponder( self.colorNameTextField )
    }
    
    @IBAction public func removeColor( _ sender: Any? )
    {
        guard let tableView = self.tableView else
        {
            return
        }
        
        if( tableView.clickedRow >= 0 )
        {
            self.arrayController?.remove( atArrangedObjectIndex: tableView.clickedRow )
        }
    }
    
    func tableView( _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int ) -> NSView?
    {
        guard let view = tableView.makeView( withIdentifier: NSUserInterfaceItemIdentifier( "Row" ), owner: self ) as? NSTableCellView else
        {
            return nil
        }
        
        for sub in view.subviews
        {
            if( sub.isKind( of: ColorView.self ) )
            {
                sub.bind( NSBindingName( "color" ), to: view, withKeyPath: "objectValue.color", options: nil )
                sub.bind( NSBindingName( "variant" ), to: view, withKeyPath: "objectValue.variant", options: nil )
            }
            else if( sub.isKind( of: NSTextField.self ) )
            {
                ( sub as? NSTextField )?.delegate = self
            }
        }
        
        return view
    }
    
    func control( _ control: NSControl, textShouldBeginEditing fieldEditor: NSText ) -> Bool
    {
        return true
    }
    
    func control( _ control: NSControl, textShouldEndEditing fieldEditor: NSText ) -> Bool
    {
        guard let textField = control as? NSTextField else
        {
            return false
        }
        
        guard let cell = control.superview as? NSTableCellView else
        {
            return false
        }
        
        guard let color = cell.objectValue as? ColorItem else
        {
            return false
        }
        
        for item in self.colors
        {
            if( item == color )
            {
                continue
            }
            
            if( textField.stringValue == item.name )
            {
                return false
            }
        }
        
        return true
    }
    
    func validateMenuItem( _ item: NSMenuItem ) -> Bool
    {
        guard let tableView = self.tableView else
        {
            return false
        }
        
        if( item.action == #selector( removeColor( _ : ) ) )
        {
            return tableView.clickedRow >= 0
        }
        
        return true
    }
}
