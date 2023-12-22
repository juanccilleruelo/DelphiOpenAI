unit MainForm;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  OpenAI.ChatGpt.ViewModel,
  OpenAI.ChatGpt.Model,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  FMX.Memo.Types,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.Edit,
  System.Json,
  Rest.Json,
  System.Generics.Collections,
  Rest.JsonReflect,
  FMX.ListBox,
  FMX.Layouts;

type
  TForm1 = class(TForm)
    MemoAnswer: TMemo;
    ComboBoxModel: TComboBox;
    Label1: TLabel;
    Layout1: TLayout;
    EditAsk: TEdit;
    BtnAsk: TButton;
    BtnCheckModerations: TButton;
    ChatGpt: TChatGpt;
    procedure BtnAskClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure EditAskChange(Sender: TObject);
    procedure EditAskKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure ChatGptError(Sender: TObject; AMessage: string);
    procedure ChatGptAnswer(Sender: TObject; AMessage: string);
    procedure ComboBoxModelChange(Sender: TObject);
    procedure ChatGptModelsLoaded(Sender: TObject; AModels: TModels);
    procedure ChatGptCompletionsLoaded(Sender: TObject; AType: TCompletions);
    procedure BtnCheckModerationsClick(Sender: TObject);
    procedure ChatGptModerationsLoaded(Sender: TObject; AType: TModerations);
  private
    FApiKey: string;
  public
    { Public-Deklarationen }
  end;

var
  Form1: TForm1;

implementation

uses
  System.IOUtils;

{$R *.fmx}

procedure TForm1.BtnAskClick(Sender: TObject);
begin
   ChatGpt.Cancel;

   if ChatGpt.Gpt35AndUp(ChatGpt.Model) then begin
      ChatGpt.Chat(EditAsk.Text);
   end
   else begin
      ChatGpt.Ask(EditAsk.Text);
   end;

   EditAsk.SetFocus;
end;

procedure TForm1.BtnCheckModerationsClick(Sender: TObject);
begin
   ChatGpt.Cancel;
   ChatGpt.ModerationInput.Input := EditAsk.Text;
   ChatGpt.LoadModerations;
   EditAsk.SetFocus;
end;

procedure TForm1.ComboBoxModelChange(Sender: TObject);
begin
   if (ComboBoxModel.ItemIndex <> -1) and (ComboBoxModel.IsFocused) then begin
      ChatGpt.Model := ComboBoxModel.Items[ComboBoxModel.ItemIndex];
   end;
end;

procedure TForm1.EditAskChange(Sender: TObject);
begin
   BtnAsk.Enabled := EditAsk.Text.Trim <> '';
end;

procedure TForm1.EditAskKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
   if Key = vkReturn then begin
      Key := 0;
      BtnAskClick(nil);
   end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
   ReportMemoryLeaksOnShutdown := True;
   if ChatGpt.ApiKey = '' then begin
      ShowMessage('ApiKey not set.');
   end
   else begin
      ChatGpt.LoadModels;
   end;
end;

procedure TForm1.ChatGptAnswer(Sender: TObject; AMessage: string);
begin
   EditAsk.Text := '';
   MemoAnswer.Lines.Add(AMessage);
end;

procedure TForm1.ChatGptCompletionsLoaded(Sender: TObject; AType: TCompletions);
begin
   Caption := AType.Model; // just testing
end;

procedure TForm1.ChatGptError(Sender: TObject; AMessage: string);
begin
   MemoAnswer.Lines.Add('Error: ' + AMessage);
end;

procedure TForm1.ChatGptModelsLoaded(Sender: TObject; AModels: TModels);
var i :Integer;
begin
   Assert(AModels <> nil);
   ComboBoxModel.Items.Clear;
   for i := 0 to AModels.Data.Count - 1 do begin
      ComboBoxModel.Items.Add(AModels.Data[i].ID);
   end;
   ComboBoxModel.ItemIndex := ComboBoxModel.Items.IndexOf(ChatGpt.Model);
   ComboBoxModel.Enabled   := ComboBoxModel.ItemIndex <> -1;
end;

procedure TForm1.ChatGptModerationsLoaded(Sender: TObject; AType: TModerations);
begin
   if AType <> nil then begin
      if AType.Results.Count > 0 then begin
         // example of how to use
         if AType.Results[0].Categories.Hate then begin
            MemoAnswer.Lines.Add('Hate included');
         end
         else begin
            MemoAnswer.Lines.Add('No Hate');
         end;

         if AType.Results[0].Categories.HateThreatening then begin
            MemoAnswer.Lines.Add('HateThreatening included');
         end
         else begin
            MemoAnswer.Lines.Add('No HateThreatening');
         end;

         if AType.Results[0].Categories.Sexual then begin
            MemoAnswer.Lines.Add('Sexual included');
         end
         else begin
            MemoAnswer.Lines.Add('No Sexual');
         end;
      end;
   end;
end;

end.
