const string pluginName = Meta::ExecutingPlugin().Name;
const string defaultText = "*Type file paths here*";
const string exampleText = """
// GetFake:
Maps/Campaigns/Training/Training - 18.Map.Gbx
Scripts/Modes/TrackMania/TM_Laps_Online.Script.txt
Libs/Nadeo/Trackmania/MainMenu/Constants.Script.txt
// GetGame:
Trackmania.exe
MaterialLib_Stadium.txt
// GetUser:
Config/Default.json
// GetProgramData:
checksum.txt
// GetResource:
Media\Texture\HotGrid.Texture.gbx
""";

#if TMNEXT
const bool OPExtractPermission = OpenplanetHasFullPermissions();
#else
const bool OPExtractPermission = true;
#endif
const bool OPDevMode = Meta::IsDeveloperMode();
const vec4 customBorderColor = vec4(UI::GetStyleColor(UI::Col::Button).xyz, 1.0f); // TODO: make this the normal button color, also force button color.

string windowLabel = "\\$b1f" + Icons::FolderOpen + "\\$z " + pluginName;
string textInput = defaultText;
array<FidData>@ foundFids = array<FidData>();

void Main()
{
	if (pluginName.EndsWith("(dev)"))
	{
		textInput = exampleText;
		windowLabel = "\\$b1f" + Icons::FolderOpen + "\\$d00 " + pluginName;
		Setting_WindowOpen = true;
	}

	auto fid = Fids::GetFake("GameData/MaterialLib_Stadium.txt");
	if (@fid != null)
	{
		trace("Fid exists!!");
		Fids::Extract(fid);
	}

	auto folder = Fids::GetGameFolder("");
	if (folder != null)
	{
		print("Folder Exists!");
		for (uint i = 0; i < folder.Leaves.Length; i++)
		{
			print(folder.Leaves[i].FullFileName);
		}
		for (uint i = 0; i < folder.Trees.Length; i++)
		{
			print(folder.Trees[i].FullDirName);
		}
	}
}

void RenderMenu()
{
	if (UI::MenuItem(windowLabel, "", Setting_WindowOpen))
		Setting_WindowOpen = !Setting_WindowOpen;
}

void RenderInterface()
{
	if (Setting_WindowOpen) 
		RenderWindow();
}

void Update(float dt)
{
	MyUI::TextFadeUpdate(dt);
}

void RenderWindow()
{
	UI::SetNextWindowSize(920, 600);
	UI::Begin(windowLabel, Setting_WindowOpen, UI::WindowFlags::NoCollapse);

	UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.5f);
	UI::PushStyleColor(UI::Col::Border, customBorderColor);
	textInput = UI::InputTextMultiline("##textInput", textInput, vec2(900, 200));
	UI::PopStyleColor();
	UI::PopStyleVar();

	if (UI::Button(Icons::Search + " Search"))
	{
		startnew(Utils::SearchForFidsCoro);
	}
	UI::SameLine();

	if (UI::Button(Icons::Kenney::Fill + " Load Example"))
	{
		textInput = exampleText;
		MyUI::TextFadeStart("Loaded an example.");
	}
	UI::SameLine();

	if (!OPExtractPermission) UI::PushStyleColor(UI::Col::Button, RedColor);
	if (UI::Button(Icons::FilesO + " Extract All Files"))
	{
		if (OPExtractPermission)
		{
			startnew(Utils::ExtractAllFilesCoro);
		}
		else
		{
			MyUI::TextFadeStart("Club access is required to extract files.", LogLevel::Error);
		}
	}
	if (!OPExtractPermission) UI::PopStyleColor();
	UI::SameLine();

	if (UI::Button(Icons::TrashO + " Clear"))
	{
		textInput = "";
		foundFids = array<FidData>();
		MyUI::TextFadeStop();
	}

	MyUI::TextFadeRender();

	if (foundFids.Length == 0 || Setting_DisableTableRender)
	{
		UI::End();
		return;
	}

	if (UI::BeginTable("table1", 4, UI::TableFlags::Resizable | UI::TableFlags::Borders))
	{
		UI::TableHeadersRow();
		
		UI::PushStyleColor(UI::Col::Separator, customBorderColor);
		MyUI::TableHeader(0, "Method");
		MyUI::TableHeader(1, "Full file path");
		MyUI::TableHeader(2, "Size");
		MyUI::TableHeader(3, "Actions");
		UI::PopStyleColor();

		for (uint i = 0; i < foundFids.Length; i++)
		{
			UI::TableNextRow();
			UI::TableSetColumnIndex(0); UI::Text(foundFids[i].method);
			UI::TableSetColumnIndex(1); UI::Text(foundFids[i].filePath);
			UI::TableSetColumnIndex(2); UI::Text(foundFids[i].fid.ByteSize + " B");
			UI::TableSetColumnIndex(3);

			if (!OPExtractPermission) 
				MyUI::RedButtonStyleColor();
			if (UI::Button("Extract##" + i))
			{
				if (OPExtractPermission)
				{
					if (Fids::Extract(foundFids[i].fid, Setting_HookMethod))
						MyUI::TextFadeStart("Successfully extracted file \"" + foundFids[i].filePath + "\"", LogLevel::Success);
					else
						MyUI::TextFadeStart("Failed to extract " + "\"" + foundFids[i].filePath + "\"", LogLevel::Error);
				}
				else
				{
					MyUI::TextFadeStart("Club access is required to extract files.", LogLevel::Error);
				}
			}
			UI::SameLine();
			MyUI::PopStyleColors();

			
			if(!OPDevMode)
				MyUI::OrangeButtonStyleColor();
			if (!OPExtractPermission || @foundFids[i].nod == null) 
				MyUI::RedButtonStyleColor();
			if (UI::Button("Nod##" + i))
			{
				if (OPDevMode && OPExtractPermission && @foundFids[i].nod != null)
				{
					auto nod = Fids::Preload(foundFids[i].fid);
					ExploreNod(foundFids[i].fid.FileName, nod);
					MyUI::TextFadeStart("Opening Nod Explorer for fid " + "\"" + foundFids[i].filePath + "\"", LogLevel::Success);
				}
				else if (!OPExtractPermission)
				{
					MyUI::TextFadeStart("Club access is required to Explore Nods.", LogLevel::Error);
				}
				else if (@foundFids[i].nod == null)
				{
					MyUI::TextFadeStart("Failed to preload nod for " + "\"" + foundFids[i].filePath + "\"", LogLevel::Error);
				}
				else if (!OPDevMode)
				{
					MyUI::TextFadeStart("Enable Developer Mode in Openplanet to Explore Nods.", LogLevel::Warning);
				}
			}
			UI::SameLine();
			MyUI::PopStyleColors();

			if (!IO::FolderExists(foundFids[i].folderPath)) 
				MyUI::RedButtonStyleColor();
			if (UI::Button("Open Folder##" + i))
			{
				if (IO::FolderExists(foundFids[i].folderPath))
				{
					MyUI::TextFadeStart("Opening folder " + "\"" + foundFids[i].folderPath + "\"");
					OpenExplorerPath(foundFids[i].folderPath);
				}
				else
				{
					MyUI::TextFadeStart("Folder " + "\"" + foundFids[i].folderPath + "\" does not exist. Extract the file to create it.", LogLevel::Error);
				}	
			}
			MyUI::PopStyleColors();

		}
		UI::EndTable();
	}

	UI::GetWindowDrawList().AddRect(UI::GetItemRect(), customBorderColor, 2.0f, 1.75f);
	UI::End();
}