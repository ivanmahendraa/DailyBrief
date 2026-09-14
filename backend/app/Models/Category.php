<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    use HasFactory;

    /**
     * The table associated with the model.
     *
     * @var string
     */
    protected $table = 'categories';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'slug',
        'description',
        'status',
    ];

    /**
     * Get the briefings associated with the category.
     */
    public function briefings(): HasMany
    {
        return $this->hasMany(Briefing::class);
    }

    /**
     * Get the articles associated with the category.
     */
    public function articles(): HasMany
    {
        return $this->hasMany(Article::class);
    }
}
