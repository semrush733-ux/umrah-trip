<?php get_header(); ?>

<div class="ut-container">
  <div class="ut-content">
    <?php if (have_posts()) : while (have_posts()) : the_post(); ?>
      <article <?php post_class(); ?>>
        <h1><a href="<?php the_permalink(); ?>"><?php the_title(); ?></a></h1>
        <?php if (is_singular()) { the_content(); } else { the_excerpt(); } ?>
      </article>
      <hr style="margin:26px 0;border:none;border-top:1px solid #eee;">
    <?php endwhile; the_posts_pagination(); ?>
    <?php else : ?>
      <h1><?php esc_html_e('Nothing found', 'umrah-trip'); ?></h1>
    <?php endif; ?>
  </div>
</div>

<?php get_footer(); ?>
