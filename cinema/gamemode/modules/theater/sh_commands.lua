CreateConVar( "cinema_url", "http://pixeltailgames.github.com/cinema/", FCVAR_REPLICATED, "Cinema url to load on theater screens." )

if CLIENT then

	CreateClientConVar( "cinema_drawnames", 1, true, false )
	CreateClientConVar( "cinema_volume", 25, true, false )
	CreateClientConVar( "cinema_hd", 0, true, false )
	CreateClientConVar( "cinema_resolution", 720, true, false )
	local ScrollAmount = CreateClientConVar( "cinema_scrollamount", 60, true, false )
	local HidePlayers = CreateClientConVar( "cinema_hideplayers", 0, true, false )
	local HideAmount = CreateClientConVar( "cinema_hide_amount", 0.04, true, false )

	cvars.AddChangeCallback( "cinema_resolution", function(cmd, old, new)
		new = tonumber(new)
		
		if !new then
			return
		elseif new < 2 then
			RunConsoleCommand( "cinema_volume", 2 )
		elseif new > 1080 then
			RunConsoleCommand( "cinema_resolution", 1080 )
		else
			theater.ResizePanel()
		end
	end)

	cvars.AddChangeCallback( "cinema_volume", function(cmd, old, new)
		new = tonumber(new)
		
		if !new then
			return
		elseif new < 0 then
			RunConsoleCommand( "cinema_volume", 0 )
		elseif new > 100 then
			RunConsoleCommand( "cinema_volume", 100 )
		else
			theater.SetVolume(new)
		end
	end)

	concommand.Add( "cinema_refresh", function()
		theater.RefreshPanel(true)
	end )

	concommand.Add( "cinema_fullscreen", theater.ToggleFullscreen )

	-- Scroll panel
	hook.Add( "PlayerBindPress", "TheaterScroll", function( ply, bind, pressed )

		local panel = theater.ActivePanel()
		if !ValidPanel(panel) then return end

		local amount = ScrollAmount:GetInt()
		if bind == "invnext" then
			panel:QueueJavascript("window.scrollBy(0,"..amount..")")
		elseif bind == "invprev" then
			panel:QueueJavascript("window.scrollBy(0,-"..amount..")")
		end

	end )

	-- Hide Players
	local amount = 0
	hook.Add( "PrePlayerDraw", "TheaterHidePlayers", function( ply )

		-- Local player in a theater and hide players enabled
		if HidePlayers:GetBool() and LocalPlayer():InTheater() then

			amount = HideAmount:GetFloat()

			-- Hide model
			render.SetBlend( amount )

			-- Hide Player Teeth/Eyes
			if ply:GetRenderMode() != RENDERGROUP_TRANSLUCENT then
				ply:SetRenderMode( RENDERGROUP_TRANSLUCENT )
				ply:SetColor( Color(255,255,255, 255 * amount ) )
				ply.Hidden = true
			end
			
		else

			-- Reset rendergroup
			if ply.Hidden and ply:GetRenderMode() != RENDERMODE_NORMAL then
				ply:SetRenderMode(RENDERMODE_NORMAL)
				ply.Hidden = false
			end

		end

	end )

	hook.Add( "PostPlayerDraw", "TheaterHidePlayers", function( ply )
		if ply.Hidden == false then
			render.SetBlend(1.0) -- always show model
			ply.Hidden = nil
		end
	end )

else

	local fcvar = { FCVAR_ARCHIVE, FCVAR_DONTRECORD }

	-- Settings
	CreateConVar( "cinema_video_duration_max", 20 * 60, fcvar, "Maximum video duration for requests in public theaters." )
	CreateConVar( "cinema_skip_ratio", 0.66, fcvar, "Ratio between 0-1 determining how many players are required to voteskip a video." )
	
	-- Permissions
	CreateConVar( "cinema_allow_url", 0, fcvar, "Allow any url to be set in private theaters." )
	CreateConVar( "cinema_allow_reset", 0, fcvar, "Reset the theater after all players have left." )
	CreateConVar( "cinema_allow_voice", 0, fcvar, "Allow theater viewers to talk amongst themselves." )
	CreateConVar( "cinema_allow_3dvoice", 1, fcvar, "Use 3D voice chat." )

	local function TheaterCommand( name, Function )

		if !Function then return end

		concommand.Add( name, function( ply, ... )

			if !IsValid(ply) then return end

			local Theater = ply:GetTheater()
			if Theater then

				local status, err = pcall(Function, Theater, ply, ...)

				if !status then
					Msg("ERROR: There was a problem running the command '" .. name .. "'\n")
					Msg(tostring(err) .. "\n")
				end

			end

		end)

	end

	TheaterCommand( "cinema_video_request", function( Theater, ply, cmd, args )

		local Video = args[1]
		if !Video then return end
		
		Theater:RequestVideo(ply, Video)

	end)

	TheaterCommand( "cinema_video_remove", function( Theater, ply, cmd, args )

		local id = tonumber(args[1])
		if !id then return end
		
		Theater:RemoveQueuedVideo(ply, id)

	end)

	TheaterCommand( "cinema_name", function( Theater, ply, cmd, args )

		local name = args[1]
		if !name then return end
		
		Theater:SetName( name, ply )

	end)

	TheaterCommand( "cinema_voteskip", function( Theater, ply, cmd, args )

		-- Prevent player from spamming command
		if ply.LastVoteSkip and ply.LastVoteSkip + 1 > CurTime() then
			return
		end

		Theater:VoteSkip(ply)

		ply.LastVoteSkip = CurTime()

	end)

	TheaterCommand( "cinema_voteup", function( Theater, ply, cmd, args )

		local QueueId = tonumber(args[1])
		if !QueueId then return end

		Theater:VoteQueuedVideo(ply, QueueId, true)

	end)

	TheaterCommand( "cinema_votedown", function( Theater, ply, cmd, args )

		local QueueId = tonumber(args[1])
		if !QueueId then return end

		Theater:VoteQueuedVideo(ply, QueueId, false)

	end)

	/*
		Admin/Developer Commands
	*/
	local function TheaterPrivilegedCommand( name, Function )

		if !Function then return end

		concommand.Add( name, function( ply, ... )

			if !IsValid(ply) then return end

			local Theater = ply:GetTheater()
			if Theater then

				if ply:IsAdmin() or
					( Theater:IsPrivate() and Theater:GetOwner() == ply ) or
					( ply.IsPixelTail && ply:IsPixelTail() ) then

					local status, err = pcall(Function, Theater, ply, ...)

					if !status then
						Msg("ERROR: There was a problem running the command '" .. name .. "'\n")
						Msg(tostring(err) .. "\n")
					end

				end

			end

		end)

	end

	TheaterPrivilegedCommand( "cinema_video_set", function( Theater, ply, cmd, args )

		local VideoUrl = args[1]
		if !VideoUrl then return end

		Theater:RequestVideo(ply, VideoUrl, true)

	end )

	TheaterPrivilegedCommand( "cinema_seek", function( Theater, ply, cmd, args )

		local seconds = tonumber(args[1])
		if !seconds then return end

		Theater:Seek(seconds)

	end )

	TheaterPrivilegedCommand( "cinema_forceskip", function( Theater, ply, cmd, args )

		local msg = {
			theater.ColHighlight,
			ply:Nick(),
			theater.ColDefault,
			" has forced to skip the current video."
		}
		Theater:AnnounceToPlayers( msg )

		Theater:SkipVideo()

	end )

	TheaterPrivilegedCommand( "cinema_lock", function( Theater, ply, cmd, args )

		Theater:ToggleQueueLock( ply )

	end )

	TheaterPrivilegedCommand( "cinema_reset", function( Theater, ply, cmd, args )

		if !ply:IsAdmin() then return end

		local msg = {
			theater.ColHighlight,
			ply:Nick(),
			theater.ColDefault,
			" has reset the theater."
		}
		Theater:AnnounceToPlayers( msg )

		Theater:Reset()

	end )

	/*
		Parse URLs in the chat for video requests
	*/
	hook.Add( "PlayerSay", "TheaterAutoAdd", function( ply, chat )

		local Theater = ply:GetTheater()
		if Theater then
			
			if theater.ExtractURLData( chat ) then
				Theater:RequestVideo( ply, chat )
				return ""
			end

		end

	end )

end