# NanoTwitter: Follow Data

This microservice is responsible for keeping track of follower/followee relationships between users. This facilitates both "follows" queries from the client app and asynchronous tweet fanouts.

Production deployment: https://nano-twitter-follow-data.herokuapp.com/

[![Codeship Status for cosi105/follow_data](https://app.codeship.com/projects/e70e2fd0-4adb-0137-db99-5e2db24b4609/status?branch=master)](https://app.codeship.com/projects/338630)
[![Maintainability](https://api.codeclimate.com/v1/badges/030697af6f74243f7b2a/maintainability)](https://codeclimate.com/github/cosi105/follow_data/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/030697af6f74243f7b2a/test_coverage)](https://codeclimate.com/github/cosi105/follow_data/test_coverage)

## Subscribed Queues

### new\_follow.user\_data

- follower_id
- follower_handle
- followee_id
- followee_handle

### new\_tweet.tweet\_data

- author_id
- tweet_id

## Published Queues

### new\_tweet.follower\_ids

- tweet_id
- follower_ids

## Caches

### follower\_id: [followee\_ids]
### follower\_id: [followee\_handles]

### followee\_id: [follower\_ids]
### followee\_id: [follower\_handles]

## Routes
