/**
 * ESC/POS thermal printer command generator
 * Builds binary ESC/POS command buffers for 58mm and 80mm thermal printers
 */

export class ESCPOSBuilder {
    static ESC = 0x1B;
    static GS = 0x1D;
    static FS = 0x1C;
    static DLE = 0x10;

    static INIT = [0x1B, 0x40];
    static CUT_FULL = [0x1D, 0x56, 0x00];
    static CUT_PARTIAL = [0x1D, 0x56, 0x01];
    
    static ALIGN_LEFT = [0x1B, 0x61, 0x00];
    static ALIGN_CENTER = [0x1B, 0x61, 0x01];
    static ALIGN_RIGHT = [0x1B, 0x61, 0x02];
    
    static BOLD_ON = [0x1B, 0x45, 0x01];
    static BOLD_OFF = [0x1B, 0x45, 0x00];
    
    static DOUBLE_HEIGHT_ON = [0x1B, 0x21, 0x10];
    static DOUBLE_WIDTH_ON = [0x1B, 0x21, 0x20];
    static DOUBLE_SIZE_ON = [0x1B, 0x21, 0x30];
    static NORMAL_SIZE = [0x1B, 0x21, 0x00];
    
    static UNDERLINE_ON = [0x1B, 0x2D, 0x01];
    static UNDERLINE_OFF = [0x1B, 0x2D, 0x00];
    
    static OPEN_DRAWER_PIN2 = [0x1B, 0x70, 0x00, 0x19, 0xFA];
    static OPEN_DRAWER_PIN5 = [0x1B, 0x70, 0x01, 0x19, 0xFA];
    
    static BARCODE_HRI_BELOW = [0x1D, 0x48, 0x02];
    static BARCODE_CODE128 = [0x1D, 0x6B, 0x49];
    
    static QR_MODEL = [0x1D, 0x28, 0x6B];

    constructor(paperWidth = 80) {
        this.paperWidth = paperWidth;
        this.charsPerLine = paperWidth === 80 ? 48 : 32;
        this.buffer = [];
    }

    reset() {
        this.buffer = [];
        return this;
    }

    _append(bytes) {
        if (Array.isArray(bytes)) {
            this.buffer.push(...bytes);
        } else if (bytes instanceof Uint8Array) {
            for (let i = 0; i < bytes.length; i++) {
                this.buffer.push(bytes[i]);
            }
        } else {
            this.buffer.push(bytes);
        }
        return this;
    }

    _encode(str) {
        // Basic ASCII encoding. For production, a library like iconv-lite or
        // a custom mapping for Code Page 22 (Arabic) is needed.
        const bytes = [];
        for (let i = 0; i < str.length; i++) {
            let code = str.charCodeAt(i);
            if (code > 255) {
                // simple fallback for unsupported characters
                bytes.push(0x3F); // '?'
            } else {
                bytes.push(code);
            }
        }
        return bytes;
    }

    _padRight(str, len) {
        if (str.length >= len) return str.substring(0, len);
        return str + ' '.repeat(len - str.length);
    }

    _padLeft(str, len) {
        if (str.length >= len) return str.substring(0, len);
        return ' '.repeat(len - str.length) + str;
    }

    _padCenter(str, len) {
        if (str.length >= len) return str.substring(0, len);
        const padLen = len - str.length;
        const padLeft = Math.floor(padLen / 2);
        const padRight = padLen - padLeft;
        return ' '.repeat(padLeft) + str + ' '.repeat(padRight);
    }

    _formatCurrency(amount, symbol = 'SAR') {
        const val = Number(amount).toFixed(2);
        return `${val} ${symbol}`;
    }

    init() {
        return this._append(ESCPOSBuilder.INIT);
    }

    text(str) {
        return this._append(this._encode(str));
    }

    newline() {
        return this._append(0x0A);
    }

    alignLeft() {
        return this._append(ESCPOSBuilder.ALIGN_LEFT);
    }

    alignCenter() {
        return this._append(ESCPOSBuilder.ALIGN_CENTER);
    }

    alignRight() {
        return this._append(ESCPOSBuilder.ALIGN_RIGHT);
    }

    bold(on = true) {
        return this._append(on ? ESCPOSBuilder.BOLD_ON : ESCPOSBuilder.BOLD_OFF);
    }

    underline(on = true) {
        return this._append(on ? ESCPOSBuilder.UNDERLINE_ON : ESCPOSBuilder.UNDERLINE_OFF);
    }

    doubleHeight() {
        return this._append(ESCPOSBuilder.DOUBLE_HEIGHT_ON);
    }

    doubleWidth() {
        return this._append(ESCPOSBuilder.DOUBLE_WIDTH_ON);
    }

    doubleSize() {
        return this._append(ESCPOSBuilder.DOUBLE_SIZE_ON);
    }

    normalSize() {
        return this._append(ESCPOSBuilder.NORMAL_SIZE);
    }

    setFontSize(width, height) {
        // width and height: 1-8
        if (width < 1) width = 1; if (width > 8) width = 8;
        if (height < 1) height = 1; if (height > 8) height = 8;
        const n = ((width - 1) << 4) | (height - 1);
        return this._append([ESCPOSBuilder.GS, 0x21, n]);
    }

    separator(char = '-') {
        return this.text(char.repeat(this.charsPerLine)).newline();
    }

    doubleSeparator(char = '=') {
        return this.text(char.repeat(this.charsPerLine)).newline();
    }

    textColumns(leftText, rightText) {
        let l = String(leftText);
        let r = String(rightText);
        let spaceLen = this.charsPerLine - l.length - r.length;
        if (spaceLen < 1) spaceLen = 1;
        return this.text(l + ' '.repeat(spaceLen) + r).newline();
    }

    textThreeColumns(left, center, right) {
        let colWidth = Math.floor(this.charsPerLine / 3);
        let l = this._padRight(String(left), colWidth);
        let c = this._padCenter(String(center), colWidth);
        let r = this._padLeft(String(right), this.charsPerLine - (colWidth * 2));
        return this.text(l + c + r).newline();
    }

    feedLines(n = 3) {
        return this._append([ESCPOSBuilder.ESC, 0x64, n]);
    }

    cut(partial = true) {
        return this._append(partial ? ESCPOSBuilder.CUT_PARTIAL : ESCPOSBuilder.CUT_FULL);
    }

    openDrawer(pin = 2) {
        return this._append(pin === 2 ? ESCPOSBuilder.OPEN_DRAWER_PIN2 : ESCPOSBuilder.OPEN_DRAWER_PIN5);
    }

    barcode(data, type = 'CODE128', height = 80, width = 2) {
        this._append([ESCPOSBuilder.GS, 0x68, height]);
        this._append([ESCPOSBuilder.GS, 0x77, width]);
        this._append(ESCPOSBuilder.BARCODE_HRI_BELOW);
        
        let typeCode = 0x49; // CODE128
        // add more types as needed
        this._append([ESCPOSBuilder.GS, 0x6B, typeCode, data.length]);
        this.text(data);
        return this.newline();
    }

    qrCode(data, size = 6) {
        const dataLen = data.length + 3;
        const pL = dataLen & 0xFF;
        const pH = (dataLen >> 8) & 0xFF;

        // Select model
        this._append([ESCPOSBuilder.GS, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
        // Set size
        this._append([ESCPOSBuilder.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);
        // Error correction level
        this._append([ESCPOSBuilder.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]);
        // Store data
        this._append([ESCPOSBuilder.GS, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
        this.text(data);
        // Print
        this._append([ESCPOSBuilder.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
        
        return this.newline();
    }

    image(imageData, width) {
        // Basic raster bit image GS v 0 implementation
        // imageData should be an array of bytes representing monochrome bitmap
        const widthBytes = Math.ceil(width / 8);
        const height = Math.floor(imageData.length / widthBytes);
        
        const xL = widthBytes & 0xFF;
        const xH = (widthBytes >> 8) & 0xFF;
        const yL = height & 0xFF;
        const yH = (height >> 8) & 0xFF;
        
        this._append([ESCPOSBuilder.GS, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
        this._append(imageData);
        return this;
    }

    buildReceipt(orderData) {
        this.init();
        
        // Header
        this.alignCenter()
            .bold(true).doubleSize()
            .text(orderData.storeName || 'Store Name').newline()
            .bold(false).normalSize()
            .text(orderData.storeAddress || '').newline()
            .text('Tel: ' + (orderData.storePhone || '')).newline()
            .text('TRN: ' + (orderData.taxRegNo || '')).newline()
            .feedLines(1)
            .alignLeft()
            .separator();
            
        // Order info
        this.textColumns('Order:', orderData.orderNumber)
            .textColumns('Date:', orderData.date)
            .textColumns('Cashier:', orderData.cashier)
            .textColumns('Terminal:', orderData.terminal)
            .separator();
            
        // Line items
        this.bold(true).textColumns('Item', 'Total').bold(false);
        if (orderData.items && orderData.items.length) {
            orderData.items.forEach(item => {
                let name = item.name;
                let details = `${item.qty} x ${this._formatCurrency(item.price)}`;
                let total = this._formatCurrency(item.qty * item.price);
                
                this.text(name).newline();
                this.textColumns(details, total);
            });
        }
        
        this.separator();
        
        // Totals
        this.textColumns('Subtotal:', this._formatCurrency(orderData.subtotal));
        if (orderData.discount > 0) {
            this.textColumns('Discount:', '-' + this._formatCurrency(orderData.discount));
        }
        this.textColumns('Tax:', this._formatCurrency(orderData.tax));
        this.separator();
        
        this.bold(true).doubleSize()
            .textColumns('TOTAL:', this._formatCurrency(orderData.total))
            .bold(false).normalSize()
            .feedLines(1);
            
        // Payments
        if (orderData.payments && orderData.payments.length) {
            orderData.payments.forEach(p => {
                this.textColumns(p.method + ':', this._formatCurrency(p.amount));
            });
            if (orderData.change > 0) {
                this.textColumns('Change:', this._formatCurrency(orderData.change));
            }
        }
        
        this.feedLines(1).separator().feedLines(1);
        
        // Footer
        this.alignCenter()
            .text('Thank you! / شكراً لزيارتكم')
            .newline().feedLines(1);
            
        // QR Code for e-invoice
        if (orderData.qrData) {
            this.qrCode(orderData.qrData, 8);
            this.feedLines(1);
        }
        
        // Barcode
        if (orderData.orderNumber) {
            this.barcode(orderData.orderNumber, 'CODE128', 60, 2);
        }
        
        this.feedLines(4).cut().openDrawer();
        
        return this;
    }

    buildXReport(shiftData) {
        this.init();
        this.alignCenter().bold(true).doubleSize().text('X - REPORT').newline();
        this.bold(false).normalSize().feedLines(1);
        
        this.alignLeft();
        this.textColumns('Shift:', shiftData.shiftId);
        this.textColumns('Opened:', shiftData.openedAt);
        this.textColumns('Generated:', shiftData.generatedAt);
        this.textColumns('Cashier:', shiftData.cashier);
        
        this.separator();
        this.textColumns('Gross Sales:', this._formatCurrency(shiftData.grossSales));
        this.textColumns('Net Sales:', this._formatCurrency(shiftData.netSales));
        this.textColumns('Tax:', this._formatCurrency(shiftData.tax));
        this.separator();
        
        this.feedLines(4).cut();
        return this;
    }

    buildZReport(shiftData) {
        this.init();
        this.alignCenter().bold(true).doubleSize().text('Z - REPORT').newline();
        this.bold(false).normalSize().feedLines(1);
        
        this.alignLeft();
        this.textColumns('Shift:', shiftData.shiftId);
        this.textColumns('Opened:', shiftData.openedAt);
        this.textColumns('Closed:', shiftData.closedAt);
        this.textColumns('Cashier:', shiftData.cashier);
        
        this.separator();
        this.textColumns('Total Sales:', this._formatCurrency(shiftData.totalSales));
        this.textColumns('Cash Returns:', this._formatCurrency(shiftData.returns));
        
        this.feedLines(4).cut();
        return this;
    }

    getBuffer() {
        return new Uint8Array(this.buffer);
    }

    getBase64() {
        const u8 = this.getBuffer();
        let binary = '';
        for (let i = 0; i < u8.byteLength; i++) {
            binary += String.fromCharCode(u8[i]);
        }
        return btoa(binary);
    }
}

// Export to window for browser use without a bundler
if (typeof window !== 'undefined') {
    window.ESCPOSBuilder = ESCPOSBuilder;
}
