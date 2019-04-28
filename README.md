# NanoTwitter: Follow Data

This microservice is responsible for keeping track of follower/followee relationships between users. This facilitates both "follows" queries from the client app and asynchronous tweet fanouts.

Production deployment: https://nano-twitter-follow-data.herokuapp.com/

[![Codeship Status for cosi105/follow_data](https://app.codeship.com/projects/e70e2fd0-4adb-0137-db99-5e2db24b4609/status?branch=master)](https://app.codeship.com/projects/338630)
[![Maintainability](https://api.codeclimate.com/v1/badges/030697af6f74243f7b2a/maintainability)](https://codeclimate.com/github/cosi105/follow_data/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/030697af6f74243f7b2a/test_coverage)](https://codeclimate.com/github/cosi105/follow_data/test_coverage)

## Message Queues

| Relation | Queue Name | Payload | Interaction |
| :------- | :--------- | :------ |:--
| Subscribes to | `new_follow.user_data` | `{follower_id, follower_handle, followee_id, followee_handle}` | Adds `follower_handle` & `follower_id` to followee's chached follower ids & handles.</br> Adds `followee_handle` & `followee_id` to follower's cached followee ids & handles.
| Subscribes to | `new_tweet.tweet_data` | `{author_id, tweet_id}` | Uses `author_id` to fetch the list of the author's `follower_id`s, adds it to payload with the `tweet_id`, then publishes it to `new_tweet.follower_ids`.
|Publishes to| `new_tweet.follower_ids` | `{tweet_id, [follower_id, ...]}`| Publishes payload as a representation of which followers' timelines need to add the new Tweet.

## Caches

### follower\_id: [followee\_ids]
### follower\_id: [followee\_handles]

### followee\_id: [follower\_ids]
### followee\_id: [follower\_handles]

## Routes

## Seeding

This service subscribes to the `follow.data.seed` queue, which the main NanoTwitter app uses to publish the user IDs and handles of every follower/followee pair, which this service then caches.