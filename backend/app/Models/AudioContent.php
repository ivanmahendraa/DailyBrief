<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AudioContent extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'audio_contents';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'briefing_id',
        'title',
        'file_path',
        'duration',
        'status',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'duration' => 'integer',
        ];
    }

    /**
     * Get the briefing that owns the audio content.
     */
    public function briefing(): BelongsTo
    {
        return $this->belongsTo(Briefing::class);
    }

    /**
     * Get the transcripts associated with the audio content.
     */
    public function transcripts(): HasMany
    {
        return $this->hasMany(Transcript::class, 'audio_id');
    }
}
