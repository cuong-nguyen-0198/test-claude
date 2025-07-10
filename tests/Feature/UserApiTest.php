<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class UserApiTest extends TestCase
{
    use RefreshDatabase, WithFaker;

    public function test_can_get_users_list(): void
    {
        User::factory(5)->create();

        $response = $this->getJson('/api/users');

        $response->assertStatus(200)
                 ->assertJson([
                     'status' => 'success',
                 ])
                 ->assertJsonStructure([
                     'status',
                     'data' => [
                         '*' => [
                             'id',
                             'name',
                             'email',
                             'created_at',
                             'updated_at',
                         ]
                     ],
                     'pagination' => [
                         'current_page',
                         'per_page',
                         'total',
                         'last_page',
                         'from',
                         'to',
                     ]
                 ]);
    }

    public function test_can_create_user(): void
    {
        $userData = [
            'name' => $this->faker->name,
            'email' => $this->faker->unique()->safeEmail,
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ];

        $response = $this->postJson('/api/users', $userData);

        $response->assertStatus(201)
                 ->assertJson([
                     'status' => 'success',
                     'message' => 'User created successfully',
                 ])
                 ->assertJsonStructure([
                     'status',
                     'message',
                     'data' => [
                         'id',
                         'name',
                         'email',
                         'created_at',
                         'updated_at',
                     ]
                 ]);

        $this->assertDatabaseHas('users', [
            'name' => $userData['name'],
            'email' => $userData['email'],
        ]);
    }

    public function test_can_show_user(): void
    {
        $user = User::factory()->create();

        $response = $this->getJson("/api/users/{$user->id}");

        $response->assertStatus(200)
                 ->assertJson([
                     'status' => 'success',
                     'data' => [
                         'id' => $user->id,
                         'name' => $user->name,
                         'email' => $user->email,
                     ]
                 ]);
    }

    public function test_can_update_user(): void
    {
        $user = User::factory()->create();
        $updateData = [
            'name' => 'Updated Name',
            'email' => 'updated@example.com',
        ];

        $response = $this->putJson("/api/users/{$user->id}", $updateData);

        $response->assertStatus(200)
                 ->assertJson([
                     'status' => 'success',
                     'message' => 'User updated successfully',
                 ]);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Updated Name',
            'email' => 'updated@example.com',
        ]);
    }

    public function test_can_delete_user(): void
    {
        $user = User::factory()->create();

        $response = $this->deleteJson("/api/users/{$user->id}");

        $response->assertStatus(200)
                 ->assertJson([
                     'status' => 'success',
                     'message' => 'User deleted successfully',
                 ]);

        $this->assertDatabaseMissing('users', [
            'id' => $user->id,
        ]);
    }

    public function test_create_user_validation_fails(): void
    {
        $response = $this->postJson('/api/users', []);

        $response->assertStatus(422)
                 ->assertJsonValidationErrors(['name', 'email', 'password']);
    }

    public function test_create_user_with_existing_email_fails(): void
    {
        $existingUser = User::factory()->create();
        
        $userData = [
            'name' => $this->faker->name,
            'email' => $existingUser->email,
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ];

        $response = $this->postJson('/api/users', $userData);

        $response->assertStatus(422)
                 ->assertJsonValidationErrors(['email']);
    }

    public function test_show_nonexistent_user_returns_404(): void
    {
        $response = $this->getJson('/api/users/999');

        $response->assertStatus(404)
                 ->assertJson([
                     'status' => 'error',
                     'message' => 'User not found',
                 ]);
    }

    public function test_update_nonexistent_user_returns_404(): void
    {
        $response = $this->putJson('/api/users/999', [
            'name' => 'Test Name',
        ]);

        $response->assertStatus(404)
                 ->assertJson([
                     'status' => 'error',
                     'message' => 'User not found',
                 ]);
    }

    public function test_delete_nonexistent_user_returns_404(): void
    {
        $response = $this->deleteJson('/api/users/999');

        $response->assertStatus(404)
                 ->assertJson([
                     'status' => 'error',
                     'message' => 'User not found',
                 ]);
    }

    public function test_password_confirmation_validation(): void
    {
        $userData = [
            'name' => $this->faker->name,
            'email' => $this->faker->unique()->safeEmail,
            'password' => 'password123',
            'password_confirmation' => 'differentpassword',
        ];

        $response = $this->postJson('/api/users', $userData);

        $response->assertStatus(422)
                 ->assertJsonValidationErrors(['password']);
    }

    public function test_users_pagination(): void
    {
        User::factory(25)->create();

        $response = $this->getJson('/api/users?per_page=10');

        $response->assertStatus(200)
                 ->assertJson([
                     'status' => 'success',
                     'pagination' => [
                         'current_page' => 1,
                         'per_page' => 10,
                         'total' => 25,
                         'last_page' => 3,
                     ]
                 ]);

        $this->assertCount(10, $response->json('data'));
    }
}