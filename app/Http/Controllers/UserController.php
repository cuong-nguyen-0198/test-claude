<?php

namespace App\Http\Controllers;

use App\Http\Requests\CreateUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Services\UserService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UserController extends Controller
{
    protected $userService;

    public function __construct(UserService $userService)
    {
        $this->userService = $userService;
    }

    public function index(Request $request): JsonResponse
    {
        $perPage = $request->get('per_page', 15);
        $users = $this->userService->getUsersPaginated($perPage);
        
        return response()->json([
            'status' => 'success',
            'data' => $users->items(),
            'pagination' => [
                'current_page' => $users->currentPage(),
                'per_page' => $users->perPage(),
                'total' => $users->total(),
                'last_page' => $users->lastPage(),
                'from' => $users->firstItem(),
                'to' => $users->lastItem(),
            ]
        ]);
    }

    public function store(CreateUserRequest $request): JsonResponse
    {
        $user = $this->userService->createUser($request->validated());
        
        return response()->json([
            'status' => 'success',
            'message' => 'User created successfully',
            'data' => $user
        ], 201);
    }

    public function show(int $id): JsonResponse
    {
        $user = $this->userService->getUserById($id);
        
        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'User not found'
            ], 404);
        }
        
        return response()->json([
            'status' => 'success',
            'data' => $user
        ]);
    }

    public function update(UpdateUserRequest $request, int $id): JsonResponse
    {
        $user = $this->userService->getUserById($id);
        
        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'User not found'
            ], 404);
        }
        
        $updated = $this->userService->updateUser($id, $request->validated());
        
        if (!$updated) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to update user'
            ], 500);
        }
        
        $updatedUser = $this->userService->getUserById($id);
        
        return response()->json([
            'status' => 'success',
            'message' => 'User updated successfully',
            'data' => $updatedUser
        ]);
    }

    public function destroy(int $id): JsonResponse
    {
        $user = $this->userService->getUserById($id);
        
        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'User not found'
            ], 404);
        }
        
        $deleted = $this->userService->deleteUser($id);
        
        if (!$deleted) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to delete user'
            ], 500);
        }
        
        return response()->json([
            'status' => 'success',
            'message' => 'User deleted successfully'
        ]);
    }
}