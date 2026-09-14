<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Transcript extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'transcripts';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'briefing_id',
        'audio_id',
        'transcript_text',
        'status',
    ];

    /**
     * Get the briefing that owns the transcript.
     */
    public function briefing(): BelongsTo
    {
        return $this->belongsTo(Briefing::class);
    }

    /**
     * Get the audio content associated with the transcript.
     */
    public function audioContent(): BelongsTo
    {
        return $this->belongsTo(AudioContent::class, 'audio_id');
    }
}
