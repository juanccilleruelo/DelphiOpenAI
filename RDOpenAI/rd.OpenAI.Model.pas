unit rd.OpenAI.Model;

interface

uses
  IdSSLOpenSSLHeaders,
  System.SysUtils,
  System.Variants,
  System.Classes,
  REST.JSON.Types,
  System.JSON,
  System.Rtti,
  System.TypInfo,
  System.Character,
  System.Math,
  System.DateUtils,
  IPPeerClient,
  REST.Client,
  REST.Authenticator.Basic,
  Data.Bind.ObjectScope,
  REST.Response.Adapter,
  REST.Types,
  REST.JSON,
  rd.OpenAI.ChatGpt,
  System.Generics.Collections;
{$METHODINFO ON}
{$M+}

type
  TGetOrFinish = (gfGet, gfFinish);
  TRequestInfoProc = procedure(AURL: string; AGetOrFinish: TGetOrFinish) of object;
  TMessageEvent = procedure(Sender: TObject; AMessage: string) of object;

  TRDOpenAIConnection = class abstract(TComponent)
  strict private
  const
    CBEARER = 'Bearer';
  public const
    CDEFAULT_USER_AGENT = 'RD OPEN AI CONNECT';
    CJSON_OPTIONS = [JoDateIsUTC, JoDateFormatISO8601, JoIgnoreEmptyArrays];
  private
    FRESTRequestParameter, FRESTRequestParameter2: TRESTRequestParameter;
    FApiKey: string;
    FTemperature: double;
    FModel: string;
    procedure SetApiKey(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property ApiKey: string read FApiKey write SetApiKey;
    property Temperature: double read FTemperature write FTemperature;
    property Model: string read FModel write FModel;
  end;

  TRDOpenAIRestClient = class abstract(TRDOpenAIConnection)
  strict private
    function GetAccept: string;
    procedure SetAccept(const Value: string);
    function GetAcceptCharset: string;
    procedure SetAcceptCharset(const Value: string);
    function GetAcceptEncoding: string;
    procedure SetAcceptEncoding(const Value: string);
    function GetBaseURL: string;
    procedure SetBaseURL(const Value: string);
    function GetProxy: string;
    procedure SetProxy(const Value: string);
    function GetProxyPort: Integer;
    procedure SetProxyPort(const Value: Integer);
  protected
    FRestClient: TCustomRESTClient;
    property BaseURL: string read GetBaseURL write SetBaseURL;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property RestClient: TCustomRESTClient read FRestClient;
  published
    property Accept: string read GetAccept write SetAccept stored True;
    property AcceptCharset: string read GetAcceptCharset write SetAcceptCharset stored True;
    property AcceptEncoding: string read GetAcceptEncoding write SetAcceptEncoding stored True;
    property Proxy: string read GetProxy write SetProxy;
    property ProxyPort: Integer read GetProxyPort write SetProxyPort;
  end;

  TRDOpenAI = class abstract(TRDOpenAIRestClient)
  strict private
    FLastError: string;
    FResponse: TRESTResponse;
    FRequest: TRESTRequest;
    FOnAnswer: TMessageEvent;
    FOnError: TMessageEvent;

    FTrimEmptyLines: Boolean;

    FCompletions: TCompletions;
    FRequestInfoProc: TRequestInfoProc;
    function GetURL: string;
    procedure SetURL(const Value: string);
  protected
    FBusy: Boolean;
    FQuestionSettings: TQuestion;
    procedure RefreshCompletions;
    function TrimText(AText: String): String;
  protected
    procedure DoAnswer(AMessage: string); virtual;
    procedure DoError(AMessage: string); virtual;
  private
    function GetCompletions: TCompletions;
  public
    property URL: string read GetURL write SetURL stored True;
    property Completions: TCompletions read GetCompletions;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Execute; virtual; abstract;
  published
    property TrimEmptyLines: Boolean read FTrimEmptyLines write FTrimEmptyLines default True;
    property OnAnswer: TMessageEvent read FOnAnswer write FOnAnswer;
    property OnError: TMessageEvent read FOnError write FOnError;
  end;

  TRDChatGpt = class(TRDOpenAI)
  strict private
    FQuestion: string;
    procedure SetQuestion(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Execute; override;
  published
    property Question: string read FQuestion write SetQuestion;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RD OpenAI', [TRDChatGpt]);
end;

constructor TRDOpenAIConnection.Create(AOwner: TComponent);
begin
  inherited;
  FRESTRequestParameter := TRESTRequestParameter.Create(nil);
  FRESTRequestParameter.Kind := PkHTTPHEADER;
  FRESTRequestParameter.Name := 'Authorization';
  FRESTRequestParameter.Options := [PoDoNotEncode];
  FRESTRequestParameter.Value := '';

  FRESTRequestParameter2 := TRESTRequestParameter.Create(nil);
  FRESTRequestParameter2.Kind := pkREQUESTBODY;
  FRESTRequestParameter2.Name := 'AnyBody';
  FRESTRequestParameter2.Value := '';
  FRESTRequestParameter2.ContentTypeStr := 'application/json';

  FTemperature := 0.0;
  FModel := '';
end;

destructor TRDOpenAIConnection.Destroy;
begin
  FreeAndNil(FRESTRequestParameter);
  FreeAndNil(FRESTRequestParameter2);
  inherited;
end;

procedure TRDOpenAIConnection.SetApiKey(const Value: string);
begin
  if FApiKey <> Value then
  begin
    FApiKey := Value;
    FRESTRequestParameter.Value := CBEARER + ' ' + Value;
  end;
end;

{ TRDOpenAIRestClient }

constructor TRDOpenAIRestClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRestClient := TCustomRESTClient.Create(Self);
  FRestClient.UserAgent := CDEFAULT_USER_AGENT;
end;

destructor TRDOpenAIRestClient.Destroy;
begin
  FreeAndNil(FRestClient);
  inherited Destroy;
end;

function TRDOpenAIRestClient.GetAccept: string;
begin
  Result := FRestClient.Accept;
end;

function TRDOpenAIRestClient.GetAcceptCharset: string;
begin
  Result := FRestClient.AcceptCharset;
end;

function TRDOpenAIRestClient.GetAcceptEncoding: string;
begin
  Result := FRestClient.AcceptEncoding;
end;

function TRDOpenAIRestClient.GetBaseURL: string;
begin
  Result := FRestClient.BaseURL;
end;

function TRDOpenAIRestClient.GetProxy: string;
begin
  Result := FRestClient.ProxyServer;
end;

function TRDOpenAIRestClient.GetProxyPort: Integer;
begin
  Result := FRestClient.ProxyPort;
end;

procedure TRDOpenAIRestClient.SetAccept(const Value: string);
begin
  FRestClient.Accept := Value;
end;

procedure TRDOpenAIRestClient.SetAcceptCharset(const Value: string);
begin
  FRestClient.AcceptCharset := Value;
end;

procedure TRDOpenAIRestClient.SetAcceptEncoding(const Value: string);
begin
  FRestClient.AcceptEncoding := Value;
end;

procedure TRDOpenAIRestClient.SetBaseURL(const Value: string);
begin
  FRestClient.BaseURL := Value;
end;

procedure TRDOpenAIRestClient.SetProxy(const Value: string);
begin
  FRestClient.ProxyServer := Value;
end;

procedure TRDOpenAIRestClient.SetProxyPort(const Value: Integer);
begin
  FRestClient.ProxyPort := Value;
end;

constructor TRDOpenAI.Create(AOwner: TComponent);
begin
  inherited;
  URL := 'https://api.openai.com/v1';
  FQuestionSettings := TQuestion.Create;
  FTrimEmptyLines := True;
end;

destructor TRDOpenAI.Destroy;
begin
  FreeAndNil(FQuestionSettings);
  FreeAndNil(FCompletions);
  FreeAndNil(FResponse);
  FreeAndNil(FRequest);
  inherited;
end;

procedure TRDOpenAI.DoAnswer(AMessage: string);
begin
  if assigned(FOnAnswer) then
  begin
    if FTrimEmptyLines then
    begin
      AMessage := TrimText(AMessage);
    end;

    FOnAnswer(Self, AMessage);
  end;
end;

procedure TRDOpenAI.DoError(AMessage: string);
begin
  if assigned(FOnError) then
  begin
    if FTrimEmptyLines then
    begin
      AMessage := TrimText(AMessage);
    end;

    FOnError(Self, AMessage);
  end;
end;

function TRDOpenAI.GetCompletions: TCompletions;
begin
  RefreshCompletions;
  Result := FCompletions;
end;

function TRDOpenAI.GetURL: string;
begin
  Result := BaseURL;
end;

procedure TRDOpenAI.RefreshCompletions;
var
  LJsonObj: TJSONObject;
  LElement: Integer;
  LVersions: TJSONArray;
begin
  if FApiKey = '' then
    raise Exception.Create('ApiKey not set.');
  if FModel = '' then
    raise Exception.Create('Model not set.');
  if FResponse = nil then
  begin
    FResponse := TRESTResponse.Create(nil);
  end;
  FResponse.RootElement := '';
  if FRequest = nil then
  begin
    FRequest := TRESTRequest.Create(nil);
  end;
  FRequest.Method := rmPOST;

  FRequest.Body.ClearBody;
  var
  s := FQuestionSettings.AsJson;

  FRequest.Params.AddItem.Assign(FRESTRequestParameter);
  FRESTRequestParameter2.Value := s;
  FRequest.Params.AddItem.Assign(FRESTRequestParameter2);

  FRequest.Client := FRestClient;
  FRequest.Resource := 'completions';
  FRequest.Response := FResponse;
  try
    if assigned(FRequestInfoProc) then
      FRequestInfoProc(FRequest.Resource, gfGet);

    FRequest.Execute;
    if assigned(FRequestInfoProc) then
      FRequestInfoProc(FRequest.Resource, gfFinish);

    LJsonObj := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetBytes(FResponse.Content), 0) as TJSONObject;
    if LJsonObj = nil then
      Exit;

    try
      FreeAndNil(FCompletions);
      FCompletions := TJson.JsonToObject<TCompletions>(TJSONObject(LJsonObj), CJSON_OPTIONS);
      if (FCompletions <> nil) and (FCompletions.Choices.Count > 0) then
      begin
        DoAnswer(FCompletions.Choices[0].Text);
      end;
    finally
      LJsonObj.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      DoError(FLastError);
    end;
  end;
end;

procedure TRDOpenAI.SetURL(const Value: string);
begin
  BaseURL := Value;
end;

function TRDOpenAI.TrimText(AText: String): String;
begin
  Result := AText;
  Result := Result.Replace(#13#10, '', [rfReplaceAll]);
  Result := Result.Replace(#13, '', [rfReplaceAll]);
  Result := Result.Replace(#10, '', [rfReplaceAll]);
end;

{ TRDChatGpt }

constructor TRDChatGpt.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TRDChatGpt.Destroy;
begin
  inherited;
end;

procedure TRDChatGpt.Execute;
begin
  if FBusy then
  begin
    asm nop;
    end;
    Exit;
  end;
  FBusy := True;
  try
    RefreshCompletions;
  finally
    FBusy := False;
  end;
end;

procedure TRDChatGpt.SetQuestion(const Value: string);
begin
  if FQuestion <> Value then
  begin
    FQuestion := Value;
    FQuestionSettings.Prompt := FQuestion;
    FQuestionSettings.Model := FModel;
    FQuestionSettings.Temperature := FTemperature
  end;
end;

end.
