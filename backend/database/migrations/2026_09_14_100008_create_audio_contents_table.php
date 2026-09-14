<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('audio_contents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('briefing_id')->unique()->constrained('briefings')->onDelete('cascade');
            $table->string('title');
            $table->string('file_path');
            $table->unsignedInteger('duration');
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('audio_contents');
    }
};
