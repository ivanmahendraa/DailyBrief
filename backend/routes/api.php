<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    $dbStatus = 'connected';
    $dbError = null;

    try {
        DB::connection()->getPdo();
    } catch (\Throwable $e) {
        $dbStatus = 'disconnected';
        $dbError = $e->getMessage();
    }

    $isHealthy = $dbStatus === 'connected';

    return response()->json([
        'success' => $isHealthy,
        'message' => $isHealthy ? 'DailyBrief API is healthy' : 'Database connection error',
        'data' => [
            'app_name' => config('app.name', 'DailyBrief'),
            'environment' => config('app.env'),
            'database' => $dbStatus,
            'timestamp' => now()->toIso8601String(),
        ],
        'errors' => $dbError ? ['database' => $dbError] : null,
    ], $isHealthy ? 200 : 503);
});

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

