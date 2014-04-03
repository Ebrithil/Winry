program pWinry;

{$APPTYPE CONSOLE}

{$R *.res}

uses
    System.Variants,
    System.StrUtils,
    System.SysUtils,
    System.Classes,
    IdComponent,
    ActiveX,
    MSHTML,
    IdHttp,
    IdURI;

type
    software = record
        dlURL,
        swName,
        fileName: string;
    end;

    TdlManager = class // Wrapper class for managing downloads
        private
            dlmax,
            dlcur,
            dlchunk:   int64;
            dlStream:  TMemoryStream;
            curSwInfo: software;
            procedure  getLinkAndDownload;
            function   dlSoftwareToMemory(URL: string): tMemoryStream;
            function   dlPageSourceToStrg(URL: string): string;
            procedure  eOnWork(aSender: tObject; aWorkMode: tWorkMode; aWorkCount: Int64);
            procedure  eOnWorkBegin(aSender: tObject; aWorkMode: tWorkMode; aWorkCountMax: Int64);
            procedure  eOnRedirect(sender: tObject; var dest: string; var numRedirect: integer; var handled: boolean; var vMethod: string);
        public
            procedure  setSoftwareInfo(info: software);
    end;

var
    // Software-related constants
    dftMaxConRetr:  byte;
    dftFileDestin:  string;
    // Main procedure-related variables
    i:              byte;
    swInfo:         array[0..2] of software;
    dwlMngr:        TdlManager;

// TdlManager Implementation
// -----------------------------------------------------------------------------
    procedure TdlManager.eOnWork(aSender: tObject; aWorkMode: tWorkMode; aWorkCount: Int64);
    begin
        if ( aWorkCount >= ( self.dlchunk * succ(self.dlcur) ) ) and (self.dlchunk > 0) then
        begin
            self.dlcur := aWorkCount div self.dlchunk;
            write(#13);
            write('Download di ' + self.curSwInfo.swName + ' in corso...');
            write( #9#9#9#9 + format('%3d', [self.dlcur]) + '%' );
        end
    end;

    procedure TdlManager.eOnWorkBegin(aSender: tObject; aWorkMode: tWorkMode; aWorkCountMax: Int64);
    begin
        self.dlcur   := 0;
        self.dlmax   := aWorkCountMax;
        self.dlchunk := self.dlmax div 100;
    end;

    procedure TdlManager.eOnRedirect(sender: tObject; var dest: string; var numRedirect: integer; var handled: boolean; var vMethod: string);
    begin
        self.curSwInfo.fileName := copy(dest, lastDelimiter('/', dest) + 1, dest.length);
        dest := tIdURI.urlEncode(dest);
    end;

    function TdlManager.dlSoftwareToMemory(URL: string): tMemoryStream;
    var
        http:  tIdHTTP;
        tries: byte;
    begin
        result               := tMemoryStream.create;
        tries                := 0;
        http                 := tIdHTTP.create;
        http.onWork          := self.eOnWork;
        http.onWorkBegin     := self.eOnWorkBegin;
        http.onRedirect      := self.eOnRedirect;
        http.handleRedirects := true;
        try
            repeat
                inc(tries);
                try
                    http.get(URL, result);
                    http.disconnect;
                    write(' OK.');
                    break;
                except
                    write(#13);
                    write('Download di ' + self.curSwInfo.swName + ' in corso...');
                    write( #9#9#9#9 + 'Re.' + intToStr(tries) );
                    write(' KO.');
                    sleep(1000);
                end;
            until (tries >= dftMaxConRetr);
            writeln;
        finally
            http.free;
        end;
    end;

    function TdlManager.dlPageSourceToStrg(URL: string): string;
    var
        http:  tIdHTTP;
        tries: byte;
    begin
        result := '';
        tries  := 0;
        http   := tIdHTTP.create;
        try
            repeat
                inc(tries);
                try
                    result := http.get(URL);
                    http.disconnect;
                    break;
                except
                    result := '';
                    sleep(1000);
                end;
            until (tries >= dftMaxConRetr);
        finally
            http.free;
        end;
    end;

    procedure TdlManager.getLinkAndDownload;

        function srcToIHTMLDocument3(srcCode: string): iHTMLDocument3;
        var
            V:       oleVariant;
            srcDoc2: iHTMLDocument2;
        begin
            coInitialize(nil);
            srcDoc2 := coHTMLDocument.create as iHTMLDocument2;
            V := varArrayCreate([0, 0], varVariant);
            V[0] := srcCode;
            srcDoc2.write( pSafeArray(tVarData(V).vArray) );
            srcDoc2.close;

            V := Unassigned;

            result := srcDoc2 as iHTMLDocument3;
        end;

    var
        i:       integer;
        fileURL: string;
        srcTags: iHTMLElementCollection;
        srcTagE: iHTMLElement;
        srcElem: iHTMLElement2;
        srcDoc3: iHTMLDocument3;

    begin
        fileURL := '';
        srcDoc3 := srcToIHTMLDocument3( dwlMngr.dlPageSourceToStrg(self.curSwInfo.dlURL) );

        // ricavo il link diretto di download
        srcTags := srcDoc3.getElementsByTagName('a');
        for i := 0 to pred(srcTags.length) do
        begin
            srcTagE := srcTags.item(i, emptyParam) as iHTMLElement;
            if (srcTagE.innerHTML = 'click here') then
            begin
                fileURL := ansiMidStr(srcTagE.outerHTML,
                           ansiPos('href', srcTagE.outerHTML),
                           lastDelimiter('"', srcTagE.outerHTML) - ansiPos('href', srcTagE.outerHTML));
                fileURL := stringReplace(fileURL, 'href="', '', [rfIgnoreCase]);
                break;
            end;
        end;

        self.dlStream :=  dwlMngr.dlSoftwareToMemory(fileURL);
        if (self.dlStream.size > 1048576) then
            self.dlStream.saveToFile( IncludeTrailingPathDelimiter(dftFileDestin) + self.curSwInfo.fileName );
    end;

    procedure TdlManager.setSoftwareInfo(info: software);
    begin
        self.curSwInfo := info;
    end;
// -----------------------------------------------------------------------------

begin
    dwlMngr := TdlManager.create;

    // Params
    dftMaxConRetr := 3;
    dftFileDestin := '.';

    // Combofix info
    swInfo[0].swName   := 'Combofix';
    swInfo[0].fileName := 'Combofix.exe';
    swInfo[0].dlURL    := 'http://www.bleepingcomputer.com/download/combofix/dl/12/';
    // TDSSKiller info
    swInfo[1].swName   := 'TDSSKiller';
    swInfo[1].fileName := 'TDSSKiller.exe';
    swInfo[1].dlURL    := 'http://www.bleepingcomputer.com/download/tdsskiller/dl/4/';
    // AdwCleaner info
    swInfo[2].swName   := 'AdwCleaner';
    swInfo[2].fileName := 'AdwCleaner.exe';
    swInfo[2].dlURL    := 'http://www.bleepingcomputer.com/download/adwcleaner/dl/125/';

    writeln('-----------------------------------');
    writeln('    __    __ _                     ');
    writeln('   / / /\ \ (_)_ __  _ __ _   _    ');
    writeln('   \ \/  \/ / | ''_ \| ''__| | | | ');
    writeln('    \  /\  /| | | | | |  | |_| |   ');
    writeln('     \/  \/ |_|_| |_|_|   \__, |   ');
    writeln('                          |___/    ');
    writeln('-----------------------------------');
    Writeln;

    // Retrieve software's download links
    for i := 0 to pred( length(swInfo) ) do
        begin
            write('Download di ' + swInfo[i].swName + ' in corso...');
            dwlMngr.setSoftwareInfo(swInfo[i]);
            dwlMngr.getLinkAndDownload;
        end;

    writeln('Fine.');
    readln;
end.
