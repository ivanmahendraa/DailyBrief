<?php

namespace Database\Seeders;

use App\Models\AppSetting;
use App\Models\Article;
use App\Models\AudioContent;
use App\Models\Briefing;
use App\Models\Category;
use App\Models\HelpContent;
use App\Models\Transcript;
use App\Models\VoiceCommand;
use Illuminate\Database\Seeder;

class DailyBriefSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // 1. Categories
        $categoriesData = [
            ['name' => 'Technology', 'slug' => 'technology', 'description' => 'Latest technology and engineering updates.', 'status' => 'active'],
            ['name' => 'Education', 'slug' => 'education', 'description' => 'Learning, research, and educational insights.', 'status' => 'active'],
            ['name' => 'Business', 'slug' => 'business', 'description' => 'Markets, startups, and economic trends.', 'status' => 'active'],
            ['name' => 'Health', 'slug' => 'health', 'description' => 'Wellness, medical science, and healthy living.', 'status' => 'active'],
            ['name' => 'Sports', 'slug' => 'sports', 'description' => 'Global sports updates, tournaments, and highlights.', 'status' => 'active'],
            ['name' => 'General', 'slug' => 'general', 'description' => 'General daily information and community news.', 'status' => 'active'],
        ];

        $categories = [];
        foreach ($categoriesData as $data) {
            $categories[$data['slug']] = Category::firstOrCreate(['slug' => $data['slug']], $data);
        }

        // 2. Featured Briefing with Audio & Transcript
        $techCategory = $categories['technology'];
        $briefing = Briefing::firstOrCreate(
            ['title' => "Today's Technology & Morning Briefing"],
            [
                'category_id' => $techCategory->id,
                'summary' => "Technology, business, and today's most important updates to start your day.",
                'content' => "Welcome to DailyBrief. Today in technology, software engineering and artificial intelligence continue to evolve rapidly. In global business, markets remain active with emerging tech investments. Have a focused and calm day.",
                'published_at' => now(),
                'status' => 'published',
            ]
        );

        $audio = AudioContent::firstOrCreate(
            ['briefing_id' => $briefing->id],
            [
                'title' => "Audio Briefing - Today's Highlights",
                'file_path' => 'audio/sample_briefing.mp3',
                'duration' => 180,
                'status' => 'active',
            ]
        );

        Transcript::firstOrCreate(
            ['briefing_id' => $briefing->id],
            [
                'audio_id' => $audio->id,
                'transcript_text' => "Welcome to DailyBrief. Today in technology, software engineering and artificial intelligence continue to evolve rapidly. In global business, markets remain active with emerging tech investments. Have a focused and calm day.",
                'status' => 'active',
            ]
        );

        // 3. Articles
        Article::firstOrCreate(
            ['title' => 'AI Development Continues to Change Software Engineering'],
            [
                'category_id' => $techCategory->id,
                'summary' => 'How modern developer tools and AI models are shifting the landscape of software engineering.',
                'content' => 'Artificial intelligence has become an everyday companion for modern software development. From real-time code assistance to automated testing, engineering teams are streamlining workflows while preserving clear architectural discipline.',
                'image_path' => null,
                'published_at' => now()->subHours(2),
                'status' => 'published',
            ]
        );

        $eduCategory = $categories['education'];
        Article::firstOrCreate(
            ['title' => 'The Value of Focused Learning in Digital Environments'],
            [
                'category_id' => $eduCategory->id,
                'summary' => 'Cultivating sustained attention and deep work habits for lifelong learning.',
                'content' => 'Digital information overload often leads to cognitive fatigue. By adopting calm, audio-first information routines and intentional learning habits, professionals can retain insights more effectively without digital fatigue.',
                'image_path' => null,
                'published_at' => now()->subHours(4),
                'status' => 'published',
            ]
        );

        // 4. Voice Commands
        $voiceCommandsData = [
            ['command_name' => 'Play Daily Briefing', 'trigger_phrase' => 'putar daily briefing', 'description' => 'Memutar audio daily briefing terbaru.', 'action' => 'PLAY_LATEST_BRIEFING', 'status' => 'active'],
            ['command_name' => 'Latest News', 'trigger_phrase' => 'berita terbaru', 'description' => 'Membuka feed berita terbaru.', 'action' => 'OPEN_LATEST_NEWS', 'status' => 'active'],
            ['command_name' => 'Technology News', 'trigger_phrase' => 'berita teknologi', 'description' => 'Memfilter berita kategori teknologi.', 'action' => 'FILTER_CATEGORY_TECH', 'status' => 'active'],
            ['command_name' => 'Today Weather', 'trigger_phrase' => 'cuaca hari ini', 'description' => 'Menampilkan info cuaca saat ini.', 'action' => 'SHOW_WEATHER', 'status' => 'active'],
            ['command_name' => 'Current Time', 'trigger_phrase' => 'jam berapa', 'description' => 'Membacakan waktu saat ini.', 'action' => 'READ_CURRENT_TIME', 'status' => 'active'],
            ['command_name' => 'Current Date', 'trigger_phrase' => 'tanggal berapa', 'description' => 'Membacakan tanggal hari ini.', 'action' => 'READ_CURRENT_DATE', 'status' => 'active'],
        ];

        foreach ($voiceCommandsData as $vc) {
            VoiceCommand::firstOrCreate(['trigger_phrase' => $vc['trigger_phrase']], $vc);
        }

        // 5. Help Contents
        $helpData = [
            ['title' => 'How to use DailyBrief', 'content' => 'DailyBrief is your calm daily information companion. Open the app to see your daily briefing, listen to audio summaries, read verified news, and check local weather effortlessly.', 'status' => 'active'],
            ['title' => 'Voice Assistant Guide', 'content' => 'Tap the microphone button to activate voice assistance. You can say commands like "Putar daily briefing", "Berita teknologi", or "Cuaca hari ini" to get instant visual and spoken responses.', 'status' => 'active'],
        ];

        foreach ($helpData as $h) {
            HelpContent::firstOrCreate(['title' => $h['title']], $h);
        }

        // 6. App Settings
        $settingsData = [
            ['key' => 'app_name', 'value' => 'DailyBrief'],
            ['key' => 'app_version', 'value' => '1.0.0'],
            ['key' => 'tagline', 'value' => 'Get Daily Information'],
            ['key' => 'default_help_message', 'value' => 'Welcome to DailyBrief'],
        ];

        foreach ($settingsData as $s) {
            AppSetting::firstOrCreate(['key' => $s['key']], $s);
        }
    }
}
