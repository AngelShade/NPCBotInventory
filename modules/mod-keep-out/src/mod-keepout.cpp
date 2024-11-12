#include "Configuration/Config.h"
#include "Player.h"
#include "Creature.h"
#include "AccountMgr.h"
#include "ScriptMgr.h"
#include "Define.h"
#include "GossipDef.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "World.h"
#include "WorldSession.h"
#include "ObjectMgr.h"
//#include <curl/curl.h>       // For Discord webhook integration
//#include <nlohmann/json.hpp> // JSON library for constructing the payload

struct MKO
{
    uint32 maxWarnings;
    bool keepOutEnabled;
    bool teleportEnabled;
    bool kickEnabled;
    bool banEnabled;
    uint32 teleportCooldown;
    uint32 firstBanDuration;
    uint32 banDurationIncrement;
    bool permanentBan;
    bool restrictSummons;
    uint32 gmBypassLevel;
    bool enableContinuousCheck;
    bool enableTimeBasedRestrictions;
    std::pair<uint32, uint32> restrictedTime; // Start/End time in hours
    float maxAllowedSpeed;
    bool checkFlyingHack;
    bool enableDiscordNotifications;
    std::string discordWebhookURL;        // Discord Webhook URL for notifications
    std::unordered_set<uint32> whitelist; // Dynamic whitelist for exempted players
};

MKO mko;

// Preloaded forbidden zones in memory
std::unordered_map<uint32, std::unordered_set<uint32>> forbiddenZones;

// Function to send notification via Discord webhook
//void SendDiscordNotification(const std::string &message)
//{
//    if (!mko.enableDiscordNotifications || mko.discordWebhookURL.empty())
//    {
//        LOG_ERROR("module", "Discord notifications are disabled or webhook URL is missing.");
//        return;
//    }

//    if (message.empty())
//    {
//        LOG_ERROR("module", "Cannot send an empty message to Discord.");
//        return;
//    }

    // Log the message we are about to send
//    LOG_INFO("module", "Sending Discord Notification: {}", message);

    // Construct the JSON payload for Discord
//    nlohmann::json jsonPayload;
//    jsonPayload["content"] = message;

    // Convert the JSON payload to a string
//    std::string payload = jsonPayload.dump();

//   CURL *curl = curl_easy_init();
//    if (curl)
//    {
//        struct curl_slist *headers = nullptr;
//        headers = curl_slist_append(headers, "Content-Type: application/json");

//        curl_easy_setopt(curl, CURLOPT_URL, mko.discordWebhookURL.c_str());
//        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
//        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.c_str());
//        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, payload.size());
//        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
//        curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 0L);

//        CURLcode res = curl_easy_perform(curl);
//        if (res != CURLE_OK)
//       {
//            LOG_ERROR("module", "Failed to send Discord notification: {}", curl_easy_strerror(res));
//        }
//
//        curl_slist_free_all(headers);
//        curl_easy_cleanup(curl);
//    }
//    else
//    {
//        LOG_ERROR("module", "Failed to initialize CURL for Discord webhook.");
//    }
//}

// Load forbidden zones into memory at startup
void LoadForbiddenZones()
{
    QueryResult result = WorldDatabase.Query("SELECT mapId, zoneId FROM `mod_mko_map_lock`");

    if (!result)
    {
        LOG_ERROR("module", "Keep Out module: No forbidden zones loaded.");
        return;
    }

    do
    {
        Field *fields = result->Fetch();
        uint32 mapId = fields[0].Get<uint32>();
        uint32 zoneId = fields[1].Get<uint32>();

        forbiddenZones[mapId].insert(zoneId);

    } while (result->NextRow());

    LOG_INFO("module", "Keep Out module: Forbidden zones loaded into memory.");
}

// Time-based zone restriction check
bool IsTimeRestricted()
{
    if (!mko.enableTimeBasedRestrictions)
        return false;

    time_t rawTime;
    struct tm *timeInfo;
    time(&rawTime);
    timeInfo = localtime(&rawTime);
    uint32 currentHour = timeInfo->tm_hour;

    return (currentHour >= mko.restrictedTime.first && currentHour <= mko.restrictedTime.second);
}

// Check if the player's current location is in a restricted zone
bool IsForbiddenZone(Player *player)
{
    if (IsTimeRestricted())
        return false;

    uint32 mapId = player->GetMapId();
    uint32 zoneId = player->GetZoneId();

    auto itr = forbiddenZones.find(mapId);
    if (itr != forbiddenZones.end() && itr->second.count(zoneId))
    {
        return true;
    }

    return false;
}

// Check if the player is on the whitelist
bool IsPlayerWhitelisted(Player *player)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    return mko.whitelist.count(accountId);
}

// Log player's entry into a restricted zone
void logPlayerExploit(uint32 accountId, uint32 mapId, uint32 zoneId)
{
    CharacterDatabase.Execute("INSERT INTO `mod_mko_map_exploit_log` (`accountId`, `timestamp`, `mapId`, `zoneId`, `action`) "
                              "VALUES ({}, UNIX_TIMESTAMP(), {}, {}, 'Entered restricted zone')",
                              accountId, mapId, zoneId);

    // Send Discord notification
    std::string message = "Player with account ID " + std::to_string(accountId) + " entered a restricted zone (Map: " + std::to_string(mapId) + ", Zone: " + std::to_string(zoneId) + ")";
  //  SendDiscordNotification(message);

    LOG_INFO("module", "Account {} entered a restricted zone at Map: {}, Zone: {}", accountId, mapId, zoneId);
}

// Revive dead players if they're in a forbidden zone
void RevivePlayerIfDead(Player *player)
{
    if (player->isDead())
    {
        player->ResurrectPlayer(100.0f);
        player->SpawnCorpseBones();
        ChatHandler(player->GetSession()).PSendSysMessage("You have been revived for entering a forbidden zone.");
        LOG_INFO("module", "Player {} revived for entering a forbidden zone while dead.", player->GetName().c_str());
    }
}

// Teleport the player to a safe location based on faction
void teleportPlayer(Player *player)
{
    if (player->GetTeamId() == TEAM_HORDE)
    {
        player->TeleportTo(1, 1629.85f, -4373.64f, 31.5573f, 3.69762f);
    }
    else
    {
        player->TeleportTo(0, -8833.38f, 628.628f, 94.0066f, 1.06535f);
    }

    ChatHandler(player->GetSession()).PSendSysMessage("You have entered a forbidden area. Your actions have been logged.");
    LOG_INFO("module", "Player {} teleported out of forbidden zone at Map: {}, Zone: {}", player->GetName().c_str(), player->GetMapId(), player->GetZoneId());

    // Send Discord notification for teleport
    std::string message = "Player " + std::string(player->GetName()) + " teleported out of forbidden zone.";
    //SendDiscordNotification(message);
}

// Ban the player for repeated violations
void banPlayer(Player *player, uint8 warnings)
{
    uint32 accountId = player->GetSession()->GetAccountId();
    std::string accountName;
    if (AccountMgr::GetName(accountId, accountName))
    {
        uint32 banDuration = mko.firstBanDuration + (warnings - 3) * mko.banDurationIncrement;

        if (mko.permanentBan)
        {
            LoginDatabase.Execute(
                "INSERT INTO `account_banned` (`id`, `bandate`, `unbandate`, `bannedby`, `banreason`, `active`) "
                "VALUES ({}, UNIX_TIMESTAMP(), 0, 'KeepOutModule', 'Repeated entry into forbidden zones', 1)",
                accountId);
            LOG_INFO("module", "Account {} permanently banned for repeated zone violations.", accountId);
        }
        else
        {
            LoginDatabase.Execute(
                "INSERT INTO `account_banned` (`id`, `bandate`, `unbandate`, `bannedby`, `banreason`, `active`) "
                "VALUES ({}, UNIX_TIMESTAMP(), UNIX_TIMESTAMP() + {}, 'KeepOutModule', 'Repeated entry into forbidden zones', 1)",
                accountId, banDuration * 60);
            LOG_INFO("module", "Account {} temporarily banned for {} minutes.", accountId, banDuration);
        }

        ChatHandler(player->GetSession()).PSendSysMessage("You have been banned for {} hours due to repeated violations of zone restrictions.", banDuration / 60);
        player->GetSession()->KickPlayer();

        // Send Discord notification for ban
        std::string message = "Player " + std::string(player->GetName()) + " banned for repeated zone violations (Ban duration: " + std::to_string(banDuration / 60) + " hours).";
       // SendDiscordNotification(message);
    }
}

// Handle player entry into restricted zones and apply appropriate actions
void checkZoneKeepOut(Player *player)
{
    if (player->GetSession()->GetSecurity() >= mko.gmBypassLevel || IsPlayerWhitelisted(player))
        return;

    if (!IsForbiddenZone(player))
        return;

    uint32 accountId = player->GetSession()->GetAccountId();
    uint8 countWarnings = 1;

    QueryResult accountWarning = CharacterDatabase.Query("SELECT count, last_warning FROM `mod_mko_map_exploit` WHERE `accountId`={}", accountId);

    if (!accountWarning)
    {
        CharacterDatabase.Execute("INSERT INTO `mod_mko_map_exploit` (`accountId`, `count`, `last_warning`) VALUES ({}, {}, UNIX_TIMESTAMP())", accountId, countWarnings);
        RevivePlayerIfDead(player);
        teleportPlayer(player);
    }
    else
    {
        uint32 lastWarning = (*accountWarning)[1].Get<uint32>();
        uint32 currentTime = time(nullptr);

        if (currentTime - lastWarning < mko.teleportCooldown)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You have recently been warned for entering a forbidden zone. Please wait before trying again.");
            return;
        }

        countWarnings = (*accountWarning)[0].Get<uint8>() + 1;

        if (countWarnings == 2)
        {
            RevivePlayerIfDead(player);
            teleportPlayer(player);
            player->GetSession()->KickPlayer("MKO: You have been kicked. If you enter this zone again, your account will be banned for 24 hours.");
        }
        else if (countWarnings == 3)
        {
            banPlayer(player, countWarnings);
        }
        else if (countWarnings > 3)
        {
            banPlayer(player, countWarnings);
        }

        CharacterDatabase.Execute("UPDATE `mod_mko_map_exploit` SET `count`={}, `last_warning`=UNIX_TIMESTAMP() WHERE `accountId`={}", countWarnings, accountId);
    }

    logPlayerExploit(accountId, player->GetMapId(), player->GetZoneId());
}

// Continuous zone check for anti-cheat measures (optional)
void ContinuousZoneCheck(Player *player)
{
    if (!mko.enableContinuousCheck)
        return;

    if (IsForbiddenZone(player))
    {
        checkZoneKeepOut(player);
    }
}

// Admin Commands for Managing Zones
class MKOCommandScript : public CommandScript
{
public:
    MKOCommandScript() : CommandScript("MKOCommandScript") {}

    std::vector<ChatCommand> GetCommands() const override
    {
        static std::vector<ChatCommand> mkoCommandTable = {
            {"addzone", SEC_ADMINISTRATOR, false, &HandleAddZoneCommand, ""},
            {"removezone", SEC_ADMINISTRATOR, false, &HandleRemoveZoneCommand, ""},
            {"listzones", SEC_ADMINISTRATOR, false, &HandleListZonesCommand, ""},
        };

        return mkoCommandTable;
    }

    static bool HandleAddZoneCommand(ChatHandler *handler, const char *args)
    {
        char *mapIdStr = strtok((char *)args, " ");
        char *zoneIdStr = strtok(nullptr, " ");
        if (!mapIdStr || !zoneIdStr)
        {
            handler->SendSysMessage("Usage: !mko addzone <mapId> <zoneId>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        uint32 mapId = atoi(mapIdStr);
        uint32 zoneId = atoi(zoneIdStr);

        forbiddenZones[mapId].insert(zoneId);
        handler->PSendSysMessage("Zone added (Map: %u, Zone: %u).", mapId, zoneId);
        return true;
    }

    static bool HandleRemoveZoneCommand(ChatHandler *handler, const char *args)
    {
        char *mapIdStr = strtok((char *)args, " ");
        char *zoneIdStr = strtok(nullptr, " ");
        if (!mapIdStr || !zoneIdStr)
        {
            handler->SendSysMessage("Usage: !mko removezone <mapId> <zoneId>");
            handler->SetSentErrorMessage(true);
            return false;
        }

        uint32 mapId = atoi(mapIdStr);
        uint32 zoneId = atoi(zoneIdStr);

        if (forbiddenZones.find(mapId) != forbiddenZones.end() && forbiddenZones[mapId].count(zoneId))
        {
            forbiddenZones[mapId].erase(zoneId);
            handler->PSendSysMessage("Zone removed (Map: %u, Zone: %u).", mapId, zoneId);
        }
        else
        {
            handler->SendSysMessage("Zone not found.");
        }
        return true;
    }

    static bool HandleListZonesCommand(ChatHandler *handler, const char * /*args*/)
    {
        handler->SendSysMessage("Restricted Zones:");
        for (const auto &mapEntry : forbiddenZones)
        {
            for (uint32 zoneId : mapEntry.second)
            {
                handler->PSendSysMessage("Map: %u, Zone: %u", mapEntry.first, zoneId);
            }
        }
        return true;
    }
};

class KeepOutPlayerScript : public PlayerScript
{
public:
    KeepOutPlayerScript() : PlayerScript("KeepOutPlayerScript") {}

    void OnLogin(Player *player) override
    {
        if (sConfigMgr->GetOption<bool>("Announcer.Enable", true))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("This server is running the |cff4CFF00Keep Out |rmodule.");
        }

        checkZoneKeepOut(player);
    }

    void OnUpdateZone(Player *player, uint32 /*newZone*/, uint32 /*newArea*/) override
    {
        checkZoneKeepOut(player);
    }

    void OnUpdate(Player *player, uint32 diff) override
    {
        ContinuousZoneCheck(player);
    }
};

class KeepOutWorldScript : public WorldScript
{
public:
    KeepOutWorldScript() : WorldScript("KeepOutWorldScript") {}

    void OnBeforeConfigLoad(bool reload) override
    {
        if (!reload)
        {
            mko.maxWarnings = sConfigMgr->GetOption<int>("MaxWarnings", 3);
            mko.keepOutEnabled = sConfigMgr->GetOption<bool>("KeepOutEnabled", true);
            mko.teleportEnabled = sConfigMgr->GetOption<bool>("KeepOutTeleportEnabled", true);
            mko.kickEnabled = sConfigMgr->GetOption<bool>("KeepOutKickPlayerEnabled", true);
            mko.banEnabled = sConfigMgr->GetOption<bool>("KeepOutBanPlayerEnabled", true);
            mko.firstBanDuration = sConfigMgr->GetOption<int>("KeepOutFirstBanDuration", 1440);
            mko.banDurationIncrement = sConfigMgr->GetOption<int>("KeepOutBanDurationIncrement", 1440);
            mko.teleportCooldown = sConfigMgr->GetOption<int>("KeepOutTeleportCooldown", 60);
            mko.restrictSummons = sConfigMgr->GetOption<bool>("KeepOutRestrictSummons", true);
            mko.gmBypassLevel = sConfigMgr->GetOption<int>("KeepOutGMBanBypassLevel", 2); // GM Level = 2 (Game Master)
            mko.enableContinuousCheck = sConfigMgr->GetOption<bool>("KeepOutEnableContinuousCheck", true);
            mko.enableTimeBasedRestrictions = sConfigMgr->GetOption<bool>("KeepOutEnableTimeBasedRestrictions", false);
            mko.restrictedTime = std::make_pair(sConfigMgr->GetOption<int>("KeepOutRestrictedTimeStart", 0), sConfigMgr->GetOption<int>("KeepOutRestrictedTimeEnd", 24));
            mko.enableDiscordNotifications = sConfigMgr->GetOption<bool>("KeepOutEnableDiscordNotifications", false);
            mko.discordWebhookURL = sConfigMgr->GetOption<std::string>("KeepOutDiscordWebhookURL", "");
        }

        LoadForbiddenZones();
    }
};

void AddKeepOutScripts()
{
    new KeepOutWorldScript();
    new KeepOutPlayerScript();
    new MKOCommandScript();
}
